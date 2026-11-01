<?php
declare(strict_types=1);
session_start();

// Cargar configuración
$config = require __DIR__ . '/config.php';
$db = $config['db'];

// Parámetros de validación y seguridad
$maxNameLen = 50;
$maxMsgLen  = 500;
$minIntervalSeconds = 10;

// CSRF token
if (empty($_SESSION['csrf'])) {
    $_SESSION['csrf'] = bin2hex(random_bytes(16));
}
$csrf = $_SESSION['csrf'];

// Conexión a la base de datos
try {
    $pdo = new PDO(
        "mysql:host={$db['host']};dbname={$db['name']};charset={$db['charset']}",
        $db['user'],
        $db['pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );
} catch (Throwable $e) {
    http_response_code(500);
    echo "<h1>Error al conectar con la base de datos</h1><pre>" .
         htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . "</pre>";
    exit;
}

// --- Enrutamiento básico ---
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$base = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/');
$route = trim(str_replace($base, '', $path), '/');

// Helper para escapar texto
function e(string $s): string {
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

// --- API JSON ---
if ($route === 'api/lista') {
    header('Content-Type: application/json; charset=utf-8');
    $stmt = $pdo->query('SELECT id, name, message, created_at FROM messages ORDER BY id DESC LIMIT 100');
    echo json_encode($stmt->fetchAll(), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// --- Insertar nuevo mensaje ---
$errors = [];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!isset($_POST['csrf']) || !hash_equals($csrf, (string)$_POST['csrf'])) {
        $errors[] = 'Sesión expirada. Recarga la página.';
    }

    $lastPost = $_SESSION['last_post_time'] ?? 0;
    if (time() - (int)$lastPost < $minIntervalSeconds) {
        $errors[] = 'Estás publicando demasiado rápido. Espera unos segundos.';
    }

    $name = trim($_POST['name'] ?? '');
    $message = trim($_POST['message'] ?? '');

    if ($name === '') {
        $errors[] = 'El nombre es obligatorio.';
    } elseif (mb_strlen($name) > $maxNameLen) {
        $errors[] = "El nombre no puede superar los {$maxNameLen} caracteres.";
    }

    if ($message === '') {
        $errors[] = 'El mensaje es obligatorio.';
    } elseif (mb_strlen($message) > $maxMsgLen) {
        $errors[] = "El mensaje no puede superar los {$maxMsgLen} caracteres.";
    }

    if (!$errors) {
        try {
            $stmt = $pdo->prepare('INSERT INTO messages (name, message, created_at) VALUES (:name, :message, NOW())');
            $stmt->execute([
                ':name' => $name,
                ':message' => $message
            ]);
            $_SESSION['last_post_time'] = time();
            header('Location: ' . $base . '/?ok=1');
            exit;
        } catch (Throwable $e) {
            $errors[] = 'Error al guardar el mensaje.';
        }
    }
}

// --- Obtener mensajes ---
$stmt = $pdo->query('SELECT id, name, message, created_at FROM messages ORDER BY id DESC LIMIT 100');
$messages = $stmt->fetchAll();
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Guestbook en PHP + MariaDB</title>
<link rel="stylesheet" href="style.css" />
<meta name="color-scheme" content="light dark">
</head>
<body>
<div class="page">
<header class="site-header">
    <h1>📖 Guestbook</h1>
    <nav>
        <a href="<?= e($base) ?>/">Mensajes</a> |
        <a href="<?= e($base) ?>/nuevo">Nuevo mensaje</a>
    </nav>
</header>

<?php if (isset($_GET['ok'])): ?>
    <div class="alert success">¡Mensaje publicado correctamente! 🎉</div>
<?php endif; ?>

<?php if ($errors): ?>
    <div class="alert error">
        <strong>Errores encontrados:</strong>
        <ul>
            <?php foreach ($errors as $err): ?>
                <li><?= e($err) ?></li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php if ($route === 'nuevo'): ?>
    <section class="card">
        <h2>Escribe un nuevo mensaje</h2>
        <form method="post" class="form">
            <input type="hidden" name="csrf" value="<?= e($csrf) ?>">
            <div class="form-row">
                <label for="name">Nombre</label>
                <input id="name" name="name" type="text" maxlength="<?= $maxNameLen ?>" required placeholder="Tu nombre">
            </div>
            <div class="form-row">
                <label for="message">Mensaje</label>
                <textarea id="message" name="message" rows="4" maxlength="<?= $maxMsgLen ?>" required placeholder="Escribe algo bonito…"></textarea>
            </div>
            <div class="form-actions">
                <button type="submit" class="btn">Publicar</button>
            </div>
            <p class="hint">Máx. <?= $maxMsgLen ?> caracteres.</p>
        </form>
    </section>

<?php elseif ($route === '' || $route === 'home'): ?>
    <section class="card">
        <h2>Mensajes recientes</h2>
        <?php if (!$messages): ?>
            <p class="empty">Aún no hay mensajes. ¡Sé la primera persona en escribir! ✍️</p>
        <?php else: ?>
            <ul class="messages">
                <?php foreach ($messages as $m): ?>
                    <li class="message">
                        <div class="message-header">
                            <strong class="author"><?= e($m['name']) ?></strong>
                            <time class="date"><?= e($m['created_at']) ?></time>
                        </div>
                        <p class="message-body"><?= nl2br(e($m['message'])) ?></p>
                    </li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </section>

<?php else: ?>
    <section class="card">
        <h2>404 - Página no encontrada</h2>
        <p>La página solicitada no existe. <a href="<?= e($base) ?>/">Volver al inicio</a>.</p>
    </section>
<?php endif; ?>

<footer class="site-footer">
    <small>Hecho con ❤️ en PHP + MariaDB</small>
</footer>
</div>
</body>
</html>
