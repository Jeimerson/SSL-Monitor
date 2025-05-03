<?php
session_start();

// === CONFIGURATION ===
define('CONFIG_FILE', __DIR__ . '/config.php');
require_once __DIR__ . '/config.php';

//$host = gethostname();
$is_logged_in = isset($_SESSION['logged_in']) && $_SESSION['logged_in'] === true;

// === SESSION TIMEOUT ===
if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity']) > SESSION_TIMEOUT) {
    session_unset();
    session_destroy();
    $is_logged_in = false;
}
$_SESSION['last_activity'] = time();

// === HANDLE LOGIN ===
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login'])) {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';

    if ($username === LOGIN_USER && $password === LOGIN_PASS) {
        $_SESSION['logged_in'] = true;
        $_SESSION['last_activity'] = time();
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Invalid username or password.']);
    }
    exit;
}

// === HANDLE LOGOUT ===
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['logout'])) {
    session_unset();
    session_destroy();
    echo json_encode(['success' => true]);
    exit;
}

// === HANDLE DOMAIN MANAGEMENT ===
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && isset($_POST['api_key'])) {
    header('Content-Type: application/json');
    $response = ['success' => false, 'message' => '', 'domains' => []];

    $action = $_POST['action'] ?? '';
    $user_key = $_POST['api_key'] ?? '';

    if ($user_key !== API_KEY || !$is_logged_in) {
        $response['message'] = 'Unauthorized.';
        echo json_encode($response);
        exit;
    }

    // === HANDLE SETTINGS SAVE ===
    if ($action === 'save_settings') {
        $config_values = [
            'API_KEY' => $_POST['API_KEY'] ?? '',
            'DOMAINS_LIST' => $_POST['DOMAINS_LIST'] ?? '',
            'CERT_STATUS_JSON' => $_POST['CERT_STATUS_JSON'] ?? '',
            'LOGIN_USER' => $_POST['LOGIN_USER'] ?? '',
            'LOGIN_PASS' => $_POST['LOGIN_PASS'] ?? '',
            'SESSION_TIMEOUT' => $_POST['SESSION_TIMEOUT'] ?? 900,
        ];

        $lines = [];
        foreach ($config_values as $key => $value) {
            $escaped = addslashes($value);
            $lines[] = "define('$key', '$escaped');";
        }

        $config_php = "<?php\n" . implode("\n", $lines) . "\n";
        $result = file_put_contents(__DIR__ . '/config.php', $config_php);

        if ($result !== false) {
            $response['success'] = true;
            $response['message'] = 'Settings saved successfully.';
        } else {
            $response['message'] = 'Failed to write config file.';
        }

        echo json_encode($response);
        exit;
    }

    // === HANDLE DOMAIN ADD/DELETE ===
    $server = trim($_POST['server'] ?? '');
    $domain = trim($_POST['domain'] ?? '');
    $port = trim($_POST['port'] ?? '443');

    if (!in_array($action, ['add', 'delete'])) {
        $response['message'] = 'Invalid action.';
    } elseif (empty($domain)) {
        $response['message'] = 'Domain is required.';
    } elseif (!is_numeric($port)) {
        $response['message'] = 'Invalid port.';
    } else {
        $new_line = "$server;$domain;$port;# AddedByUser";
        $fp = fopen(DOMAINS_LIST, 'c+');
        if (flock($fp, LOCK_EX)) {
            $lines = [];
            while (($line = fgets($fp)) !== false) {
                $lines[] = rtrim($line);
            }

            $result = false;
            if ($action === 'add') {
                if (!in_array($new_line, $lines)) {
                    $lines[] = $new_line;
                    $result = true;
                    $response['message'] = "Domain added: $domain";
                } else {
                    $response['message'] = "Domain already exists: $domain";
                }
            } elseif ($action === 'delete') {
                $before = count($lines);
                $lines = array_filter($lines, function ($line) use ($domain) {
                    return !(strpos($line, ";$domain;") !== false && strpos($line, '# AddedByUser') !== false);
                });
                $after = count($lines);
                if ($before !== $after) {
                    $result = true;
                    $response['message'] = "Domain deleted: $domain";
                } else {
                    $response['message'] = "Domain not found: $domain";
                }
            }

            if ($result) {
                ftruncate($fp, 0);
                rewind($fp);
                fwrite($fp, implode("\n", $lines) . "\n");
                $response['success'] = true;
            }
            flock($fp, LOCK_UN);
        }
        fclose($fp);
    }

    $response['domains'] = loadDomains();
    echo json_encode($response);
    exit;
}

// === FETCH DOMAINS OR CERT STATUS ===
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['fetch_domains'])) {
    header('Content-Type: application/json');
    echo json_encode([
        'domains' => loadDomains(),
        'certs' => loadCertStatus(),
        'logged_in' => $is_logged_in
    ]);
    exit;
}

// === FETCH SETTINGS ===
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['get_settings'])) {
    header('Content-Type: application/json');
    echo json_encode([
        'API_KEY' => defined('API_KEY') ? API_KEY : '',
        'DOMAINS_LIST' => defined('DOMAINS_LIST') ? DOMAINS_LIST : '',
        'CERT_STATUS_JSON' => defined('CERT_STATUS_JSON') ? CERT_STATUS_JSON : '',
        'LOGIN_USER' => defined('LOGIN_USER') ? LOGIN_USER : '',
        'LOGIN_PASS' => defined('LOGIN_PASS') ? LOGIN_PASS : '',
        'SESSION_TIMEOUT' => defined('SESSION_TIMEOUT') ? SESSION_TIMEOUT : ''
    ]);
    exit;
}

// === FUNCTIONS ===
function loadDomains() {
    $domains = [];
    if (file_exists(DOMAINS_LIST)) {
        $all_lines = file(DOMAINS_LIST, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($all_lines as $line) {
            if (strpos($line, '# AddedByUser') !== false) {
                $parts = explode(';', $line);
                $domains[] = ['domain' => $parts[1], 'port' => $parts[2]];
            }
        }
    }
    return $domains;
}

function loadCertStatus() {
    if (file_exists(CERT_STATUS_JSON)) {
        $data = json_decode(file_get_contents(CERT_STATUS_JSON), true);
        if (is_array($data)) {
            $certs = [];
            foreach ($data as $item) {
                $status_full = $item['status'] ?? '';
                $days_left = null;
                $status_simple = $status_full;
                
                if (preg_match('/expires in ([0-9]+) days/', $status_full, $matches)) {
                    $days_left = (int)$matches[1];
                    $status_simple = 'Valid';
                } elseif (stripos($status_full, 'expired') !== false) {
                    $days_left = 0;
                    $status_simple = 'Expired';
                } else {
                    $days_left = -1;
                    $status_simple = 'Error';

                // Append full message in parentheses if it's not empty
                    if (!empty($status_full)) {
                        $status_simple = 'Error<br><small>(' . htmlspecialchars($status_full) . ')</small>';
                    }
                }

                $certs[] = [
                    'server' => $item['server'] ?? '',
                    'domain' => $item['domain'] ?? '',
                    'port' => isset($item['port']) ? (int)$item['port'] : 443,
                    'status' => $status_simple,
                    'days_left' => $days_left
                ];
            }

            usort($certs, function ($a, $b) {
                return $a['days_left'] <=> $b['days_left'];
            });

            return $certs;
        }
    }
    return [];
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>SSL Monitor</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>

<div class="topbar">
    <h2>SSL Monitor</h2>
    <div class="topbar-buttons">
        <button id="settingsBtn" style="display:none;">⚙️ Settings</button>
        <button id="loginBtn" style="display:none;"></button>
    </div>
</div>

<div class="container" id="content">
    <!-- Dynamic content loads here via JS -->
</div>

<script>
    window.API_KEY = <?php echo $is_logged_in ? json_encode(API_KEY) : 'null'; ?>;
    window.isLoggedIn = <?php echo $is_logged_in ? 'true' : 'false'; ?>;
</script>
<script src="script.js"></script>

</body>
</html>
