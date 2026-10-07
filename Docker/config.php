<?php
// Moodle-Konfiguration für den Docker-Stack.
// Alle Werte kommen aus Umgebungsvariablen (siehe docker-compose.yaml),
// damit das Image unverändert in verschiedenen Umgebungen laufen kann.

unset($CFG);
global $CFG;
$CFG = new stdClass();

$env = static function (string $name, string $default): string {
    $value = getenv($name);
    return ($value === false || $value === '') ? $default : $value;
};

$CFG->dbtype    = $env('MOODLE_DB_TYPE', 'pgsql');
$CFG->dblibrary = 'native';
$CFG->dbhost    = $env('MOODLE_DB_HOST', 'postgres');
$CFG->dbname    = $env('MOODLE_DB_NAME', 'moodle');
$CFG->dbuser    = $env('MOODLE_DB_USER', 'postgres');
$CFG->dbpass    = $env('MOODLE_DB_PASSWORD', '');
$CFG->prefix    = $env('MOODLE_DB_PREFIX', 'mdl_');
$CFG->dboptions = [
    'dbpersist' => 0,
    'dbport'    => (int) $env('MOODLE_DB_PORT', '5432'),
    'dbsocket'  => '',
];

$CFG->wwwroot  = $env('MOODLE_WWWROOT', 'http://localhost');
$CFG->dataroot = $env('MOODLE_DATAROOT', '/var/www/moodledata');
$CFG->admin    = 'admin';

$CFG->directorypermissions = 02777;

// nginx leitet unbekannte Pfade an r.php weiter (siehe Docker/nginx.conf).
$CFG->routerconfigured = true;

// Entwicklungseinstellungen
if ($env('MOODLE_DEBUG', '1') === '1') {
    $CFG->debug = E_ALL;
    $CFG->debugdisplay = 1;
}

// Zusätzliche Einstellungen, z.B. für eigene Plugins: alle *.php aus einem eingehängten
// Ordner einbinden (siehe docker-compose.yaml, config.d). Dort sind $CFG und $env verfügbar.
foreach (glob('/var/www/config.d/*.php') ?: [] as $extraconfig) {
    require $extraconfig;
}

require_once(__DIR__ . '/lib/setup.php');
