<?php
///////// apcu
$stats = apcu_cache_info(true);
$fields = array(
    'num_slots',
    'num_hits',
    'num_misses',
);
foreach ($fields as $f) {
    echo "# TYPE apcu_$f counter\n";
    echo "apcu_$f ".$stats[$f]."\n";
}

$stats = apcu_sma_info(true);
$fields = array(
    'num_seg',
    'seg_size',
    'avail_mem',
);
foreach ($fields as $f) {
    echo "# TYPE apcu_$f gauge\n";
    echo "apcu_$f ".$stats[$f]."\n";
}

///////// opcache
$stats = opcache_get_status(false);
$fields = array(
    'used_memory',
    'free_memory',
    'wasted_memory',
);
foreach ($fields as $f) {
    echo "# TYPE opcache_memory_usage_$f gauge\n";
    echo "opcache_memory_usage_$f ".$stats['memory_usage'][$f]."\n";
}
$fields = array(
    'buffer_size',
    'used_memory',
    'free_memory',
    'number_of_strings',
);
foreach ($fields as $f) {
    echo "# TYPE opcache_interned_strings_usage_$f gauge\n";
    echo "opcache_interned_strings_usage_$f ".$stats['interned_strings_usage'][$f]."\n";
}

////////// apache
$status = file_get_contents('http://localhost:8081/status/apache/?auto');
preg_match_all('#^([A-Z ]+?): (.*)$#im', $status, $m);
$stats = array();
foreach (array_keys($m[0]) as $i) {
    $stats[$m[1][$i]] = $m[2][$i];
}

echo "# TYPE apache_accesses_total counter\n";
echo "apache_accesses_total ".$stats['Total Accesses']."\n";

echo "# TYPE apache_cpuload gauge\n";
echo "apache_cpuload ".$stats["CPULoad"]."\n";

$scoreboard = $stats["Scoreboard"];
echo "# TYPE apache_scoreboard gauge\n";
echo "apache_scoreboard{state=\"closing\"} ".substr_count($scoreboard, "C")."\n";
echo "apache_scoreboard{state=\"dns\"} ".substr_count($scoreboard, "D")."\n";
echo "apache_scoreboard{state=\"graceful_stop\"} ".substr_count($scoreboard, "G")."\n";
echo "apache_scoreboard{state=\"idle\"} ".substr_count($scoreboard, "_")."\n";
echo "apache_scoreboard{state=\"idle_cleanup\"} ".substr_count($scoreboard, "I")."\n";
echo "apache_scoreboard{state=\"keepalive\"} ".substr_count($scoreboard, "K")."\n";
echo "apache_scoreboard{state=\"logging\"} ".substr_count($scoreboard, "L")."\n";
echo "apache_scoreboard{state=\"open_slot\"} ".substr_count($scoreboard, ".")."\n";
echo "apache_scoreboard{state=\"read\"} ".substr_count($scoreboard, "R")."\n";
echo "apache_scoreboard{state=\"reply\"} ".substr_count($scoreboard, "W")."\n";
echo "apache_scoreboard{state=\"startup\"} ".substr_count($scoreboard, "S")."\n";

echo "# TYPE apache_sent_kilobytes_total counter\n";
echo "apache_sent_kilobytes_total ".($stats['Total kBytes']*1024)."\n";

echo "# TYPE apache_up gauge\n";
echo "apache_up 1\n";

echo "# TYPE apache_uptime_seconds_total counter\n";
echo "apache_uptime_seconds_total ".$stats['ServerUptimeSeconds']."\n";

echo "# TYPE apache_workers gauge\n";
echo "apache_workers{state=\"busy\"} ".$stats['BusyWorkers']."\n";
echo "apache_workers{state=\"idle\"} ".$stats['IdleWorkers']."\n";


///////// memory
$stat = file_get_contents('/sys/fs/cgroup/memory/memory.stat');
preg_match_all('#^([A-Z_]+?) (.*)$#im', $stat, $m);
$stats = array();
foreach (array_keys($m[0]) as $i) {
    $stats[$m[1][$i]] = $m[2][$i];
}
$fields = array(
    'total_cache',
    'total_rss',
    'total_rss_huge',
);
foreach ($fields as $f) {
    echo "# TYPE memory_$f gauge\n";
    echo "memory_$f ".$stats[$f]."\n";
}
