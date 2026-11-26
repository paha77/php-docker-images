<?php
// Independent security floors; PHP 8.3 includes the November 2026 security release.
$branch = implode('.', array_slice(explode('.', $argv[1]), 0, 2));
$floors = ['8.2' => '8.2.35', '8.3' => '8.3.37', '8.4' => '8.4.27'];
$actualBranch = PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;
if (!isset($floors[$branch]) || $actualBranch !== $branch) {
    fwrite(STDERR, "Unsupported/mismatched PHP branch for {$argv[1]}\n");
    exit(2);
}
if (!version_compare(PHP_VERSION, $floors[$branch], '>=') ||
    !version_compare(PHP_VERSION, $argv[1], '>=')) {
    fwrite(STDERR, 'PHP ' . PHP_VERSION . " fails branch/security minimum for {$argv[1]}\n");
    exit(1);
}
