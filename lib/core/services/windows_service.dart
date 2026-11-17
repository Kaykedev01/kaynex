part of '../../main.dart';

/// Acesso somente leitura ao Windows e utilitários de diagnóstico locais.
class WindowsService {
  static final Map<int, ({double seconds, DateTime at})> _cpuSamples = {};

  static Future<dynamic> powershell(String script) async {
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add((unit >> 8) & 0xff);
    }
    final encoded = base64.encode(bytes);
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encoded,
    ], runInShell: false).timeout(const Duration(seconds: 20));
    if (result.exitCode != 0) {
      final error = (result.stderr as String).trim();
      throw ProcessException(
        'powershell.exe',
        const [],
        error.isEmpty ? 'Consulta ao Windows falhou.' : error,
        result.exitCode,
      );
    }
    final output = (result.stdout as String).trim();
    if (output.isEmpty) return null;
    return jsonDecode(output);
  }

  static Future<Map<String, dynamic>> system() async {
    final value = await powershell(r'''
$os=Get-CimInstance Win32_OperatingSystem
$cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
$board=Get-CimInstance Win32_BaseBoard | Select-Object -First 1
$perf=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
$diskPerf=Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction SilentlyContinue
$logical=@(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { [pscustomobject]@{ Name=$_.DeviceID; Label=$_.VolumeName; Size=[double]$_.Size; Free=[double]$_.FreeSpace } })
$physical=@(Get-CimInstance Win32_DiskDrive | ForEach-Object { [pscustomobject]@{ Model=$_.Model; Size=[double]$_.Size; Interface=$_.InterfaceType } })
$gpu=@(Get-CimInstance Win32_VideoController | ForEach-Object { [pscustomobject]@{ Name=$_.Name; AdapterRAM=$_.AdapterRAM; DriverVersion=$_.DriverVersion } })
[pscustomobject]@{ Computer=$env:COMPUTERNAME; Windows=$os.Caption; Version=$os.Version; Build=$os.BuildNumber; Architecture=$os.OSArchitecture; Cpu=$cpu.Name.Trim(); Cores=$cpu.NumberOfCores; Threads=$cpu.NumberOfLogicalProcessors; CpuLoad=$perf.PercentProcessorTime; CpuFallback=$cpu.LoadPercentage; BoardManufacturer=$board.Manufacturer; BoardModel=$board.Product; RamTotal=[double]$os.TotalVisibleMemorySize*1KB; RamFree=[double]$os.FreePhysicalMemory*1KB; UptimeSeconds=[math]::Max(0,((Get-Date)-$os.LastBootUpTime).TotalSeconds); Disks=$logical; PhysicalDisks=$physical; Gpus=$gpu; DiskReadBytesPerSec=$diskPerf.DiskReadBytesPersec; DiskWriteBytesPerSec=$diskPerf.DiskWriteBytesPersec } | ConvertTo-Json -Depth 5 -Compress
''');
    return Map<String, dynamic>.from(value as Map);
  }

  static Future<Map<String, dynamic>> sample() async {
    final value = await powershell(r'''
$os=Get-CimInstance Win32_OperatingSystem
$cpu=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
$disk=Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction SilentlyContinue
[pscustomobject]@{Cpu=$cpu.PercentProcessorTime; RamTotal=[double]$os.TotalVisibleMemorySize*1KB; RamAvailable=[double]$os.FreePhysicalMemory*1KB; ReadBytes=[double]$disk.DiskReadBytesPersec; WriteBytes=[double]$disk.DiskWriteBytesPersec; At=(Get-Date).ToString('o')} | ConvertTo-Json -Compress
''');
    return Map<String, dynamic>.from(value as Map);
  }

  static Future<List<Map<String, dynamic>>> adapters() async {
    final value = await powershell(r'''
$configs=@(Get-CimInstance Win32_NetworkAdapterConfiguration)
$rows=@(Get-CimInstance Win32_NetworkAdapter | ForEach-Object { $a=$_; $c=$configs | Where-Object InterfaceIndex -eq $a.InterfaceIndex | Select-Object -First 1; [pscustomobject]@{ Name=$a.NetConnectionID; Description=$a.Name; Status=$a.NetEnabled; Mac=$a.MACAddress; Speed=$a.Speed; IPv4=@($c.IPAddress | Where-Object {$_ -notmatch ':'}); IPv6=@($c.IPAddress | Where-Object {$_ -match ':'}); Gateways=@($c.DefaultIPGateway); Dns=@($c.DNSServerSearchOrder) } })
$rows | ConvertTo-Json -Depth 4 -Compress
''');
    if (value == null) return [];
    return (value is List ? value : [value])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> processes() async {
    final value = await powershell(
      r'''@(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 350 @{n='Name';e={$_.ProcessName}},Id,@{n='Memory';e={$_.WorkingSet64}},@{n='CpuSeconds';e={if($_.CPU -ne $null){[double]$_.CPU}else{0}}},@{n='Path';e={try{$_.Path}catch{$null}}}) | ConvertTo-Json -Depth 3 -Compress''',
    );
    if (value == null) return [];
    final now = DateTime.now();
    final rows = (value is List ? value : [value])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final current = <int, ({double seconds, DateTime at})>{};
    for (final row in rows) {
      final pid = row['Id'] as int;
      final seconds = (row['CpuSeconds'] as num?)?.toDouble() ?? 0;
      final prior = _cpuSamples[pid];
      final elapsed = prior == null
          ? 0.0
          : now.difference(prior.at).inMilliseconds / 1000;
      row['CpuPercent'] = prior == null || elapsed <= 0
          ? null
          : (((seconds - prior.seconds).clamp(0, double.infinity) / elapsed) /
                    Platform.numberOfProcessors *
                    100)
                .clamp(0, 100);
      current[pid] = (seconds: seconds, at: now);
    }
    _cpuSamples
      ..clear()
      ..addAll(current);
    return rows;
  }

  static Future<void> endProcess(int pid) async {
    if (pid < 1) throw ArgumentError('PID inválido.');
    await powershell(
      r'''$p=Get-Process -Id '''
      '$pid'
      r''' -ErrorAction Stop; $protected=@('system','registry','smss','csrss','wininit','services','lsass','winlogon','fontdrvhost','dwm','kaynex'); if($protected -contains $p.ProcessName.ToLowerInvariant()){throw 'Este é um processo protegido.'}; Stop-Process -Id '''
      '$pid'
      r''' -ErrorAction Stop; 'OK' ''',
    );
  }

  static Future<List<Map<String, dynamic>>> files(String path) async {
    final dir = Directory(path);
    final items = <Map<String, dynamic>>[];
    await for (final entity in dir.list(followLinks: false)) {
      try {
        final stat = await entity.stat();
        items.add({
          'path': entity.path,
          'name': entity.uri.pathSegments.where((e) => e.isNotEmpty).last,
          'directory': entity is Directory,
          'size': stat.size,
          'modified': stat.modified,
        });
      } on FileSystemException {
        // Entradas sem permissão são omitidas sem interromper a navegação.
      }
    }
    items.sort((a, b) {
      if (a['directory'] != b['directory']) {
        return (a['directory'] as bool) ? -1 : 1;
      }
      return (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      );
    });
    return items;
  }

  static Future<Map<String, dynamic>> ping(String host) async {
    final result = await pingMany(host, 1);
    return {
      'ok': result['ok'],
      'message': result['average'] == null
          ? 'Sem resposta dentro do limite.'
          : '${result['average']} ms',
      'ms': result['average'],
    };
  }

  static Future<Map<String, dynamic>> pingMany(String host, int count) async {
    _validateHost(host);
    if (count < 1 || count > 20) {
      throw ArgumentError('Use entre 1 e 20 pacotes.');
    }
    final watch = Stopwatch()..start();
    final process = await Process.run('ping.exe', [
      '-n',
      '$count',
      '-w',
      '1800',
      host,
    ], runInShell: false).timeout(Duration(seconds: count * 2 + 3));
    watch.stop();
    final output = '${process.stdout}\n${process.stderr}';
    final values = RegExp(
      r'(?:tempo|time)[=<]\s*(\d+)\s*ms',
      caseSensitive: false,
    ).allMatches(output).map((m) => int.parse(m.group(1)!)).toList();
    final loss =
        RegExp(
          r'(\d+)%\s*(?:de\s*)?(?:perdidos|loss)',
          caseSensitive: false,
        ).firstMatch(output) ??
        RegExp(r'\((\d+)%\s*loss\)', caseSensitive: false).firstMatch(output);
    final lostPercent =
        int.tryParse(loss?.group(1) ?? '') ??
        (values.length == count
            ? 0
            : ((count - values.length) / count * 100).round());
    return {
      'ok': process.exitCode == 0 && values.isNotEmpty,
      'count': count,
      'received': values.length,
      'loss': lostPercent,
      'min': values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b),
      'average': values.isEmpty
          ? null
          : (values.reduce((a, b) => a + b) / values.length).round(),
      'max': values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b),
      'elapsedMs': watch.elapsedMilliseconds,
      'output': output.trim(),
    };
  }

  static Future<List<String>> dns(String host) async {
    _validateHost(host);
    return (await InternetAddress.lookup(host))
        .map((address) => '${address.address} (${address.type.name})')
        .toSet()
        .toList();
  }

  static Future<String> trace(String host) async {
    _validateHost(host);
    final result = await Process.run('tracert.exe', [
      '-d',
      '-h',
      '12',
      '-w',
      '700',
      host,
    ], runInShell: false).timeout(const Duration(seconds: 22));
    return '${result.stdout}'.trim();
  }

  static Future<Map<String, dynamic>> tcpTest(String host, int port) async {
    _validateHost(host);
    if (port < 1 || port > 65535) {
      throw ArgumentError('A porta deve ficar entre 1 e 65535.');
    }
    final watch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      watch.stop();
      return {
        'ok': true,
        'latencyMs': watch.elapsedMilliseconds,
        'message': 'Conexão TCP estabelecida.',
      };
    } on SocketException catch (error) {
      watch.stop();
      return {
        'ok': false,
        'latencyMs': watch.elapsedMilliseconds,
        'message': error.message,
      };
    } finally {
      socket?.destroy();
    }
  }

  static void _validateHost(String host) {
    if (!RegExp(r'^[a-zA-Z0-9.-]{1,253}$').hasMatch(host)) {
      throw ArgumentError('Informe um domínio ou endereço IP válido.');
    }
  }
}
