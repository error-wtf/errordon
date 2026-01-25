// Matrix Rain
const matrixCanvas = document.getElementById('matrixCanvas');
const matrixCtx = matrixCanvas.getContext('2d');
matrixCanvas.width = window.innerWidth;
matrixCanvas.height = window.innerHeight;

const MATRIX_CHARS = 'アァカサタナハマヤャラワガザダバパイィキシチニヒミリギジヂビピウゥクスツヌフムユュルグズヅブプエェケセテネヘメレゲゼデベペオォコソトノホモヨョロゴゾドボポヴッン0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const fontSize = 16;
let columns = Math.floor(matrixCanvas.width / fontSize);
let drops = Array.from({ length: columns }, () => Math.random() * matrixCanvas.height / fontSize);
let rainActive = true;

function drawMatrixRain() {
    if (!rainActive) return;
    
    matrixCtx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    matrixCtx.fillRect(0, 0, matrixCanvas.width, matrixCanvas.height);
    matrixCtx.fillStyle = '#0F0';
    matrixCtx.font = `${fontSize}px monospace`;
    
    for (let i = 0; i < columns; i++) {
        const text = MATRIX_CHARS.charAt(Math.floor(Math.random() * MATRIX_CHARS.length));
        const x = i * fontSize;
        const y = drops[i] * fontSize;
        matrixCtx.fillText(text, x, y);
        
        if (y > matrixCanvas.height && Math.random() > 0.975) {
            drops[i] = 0;
        }
        drops[i] += 0.3 + Math.random() * 0.4;
    }
}

setInterval(drawMatrixRain, 50);

window.addEventListener('resize', () => {
    matrixCanvas.width = window.innerWidth;
    matrixCanvas.height = window.innerHeight;
    columns = Math.floor(matrixCanvas.width / fontSize);
    drops = Array.from({ length: columns }, () => Math.random() * matrixCanvas.height / fontSize);
});

// Terminal System
const output = document.getElementById('output');
const commandInput = document.getElementById('commandInput');
const terminal = document.getElementById('terminal');
const loginScreen = document.getElementById('loginScreen');
const usernameInput = document.getElementById('usernameInput');
const promptEl = document.getElementById('prompt');

let username = 'guest';
let talkMode = null;

// Login
function login() {
    const name = usernameInput.value.trim();
    if (name) {
        username = name.toLowerCase().replace(/[^a-z0-9]/g, '');
        localStorage.setItem('matrixUsername', username);
    }
    
    loginScreen.style.display = 'none';
    terminal.style.cssText = 'display: flex !important;';
    promptEl.textContent = `${username}@errordon:~$`;
    commandInput.focus();
    
    printLine('╔════════════════════════════════════════════════════════════╗', 'output-line');
    printLine('║         WELCOME TO ERRORDON - A SAFE FEDIVERSE             ║', 'output-line');
    printLine('║                                                            ║', 'output-line');
    printLine('║  🛡️  NO PORN • NO HATE • NO FASCISM                         ║', 'output-line');
    printLine('║                                                            ║', 'output-line');
    printLine('║  Type "enter matrix" to access the social network          ║', 'output-line');
    printLine('║  Type "help" for all available commands                    ║', 'output-line');
    printLine('╚════════════════════════════════════════════════════════════╝', 'output-line');
    printLine('', 'output-line');
    printLine(`Connected as: ${username}`, 'output-line');
    printLine('', 'output-line');
}

function logout() {
    terminal.style.display = 'none';
    loginScreen.style.display = 'block';
    output.innerHTML = '';
    usernameInput.value = '';
    usernameInput.focus();
}

// Load username on enter
usernameInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') login();
});

// Auto-login if username stored
window.addEventListener('load', () => {
    const stored = localStorage.getItem('matrixUsername');
    if (stored) {
        usernameInput.value = stored;
    }
});

// Listen for messages from Tetris iframe
window.addEventListener('message', (event) => {
    if (event.data === 'closeTetris') {
        const overlay = document.getElementById('tetrisOverlay');
        const iframe = document.getElementById('tetrisFrame');
        overlay.style.display = 'none';
        iframe.src = ''; // Clear iframe
    }
});

// Terminal Commands
const commands = {
    help: 'Available commands: help, clear, rain, quote, hack, talk <character>, date, whoami, echo <text>, tetris, exit',
    clear: () => { output.innerHTML = ''; return ''; },
    date: () => new Date().toString(),
    whoami: () => username,
    exit: 'Type "clear" to clear screen or logout to disconnect'
};

function printLine(text, className = 'output-line') {
    const line = document.createElement('div');
    line.className = className;
    line.textContent = text;
    output.appendChild(line);
    output.scrollTop = output.scrollHeight;
}

function printHTML(html) {
    const div = document.createElement('div');
    div.className = 'output-line';
    div.innerHTML = html;
    output.appendChild(div);
    output.scrollTop = output.scrollHeight;
}

commandInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
        const cmd = commandInput.value.trim();
        if (cmd) {
            printLine(`${username}@errordon:~$ ${cmd}`, 'command-line');
            handleCommand(cmd);
        }
        commandInput.value = '';
    }
});

function handleCommand(input) {
    const lower = input.toLowerCase();
    const parts = input.split(' ');
    const cmd = parts[0].toLowerCase();
    const args = parts.slice(1);
    
    // Talk mode active
    if (talkMode) {
        handleTalkInput(input);
        return;
    }
    
    // ENTER MATRIX - Go to Mastodon
    if (lower === 'enter matrix' || lower === 'entermatrix' || lower === 'login') {
        printLine('[INITIATING NEURAL INTERFACE...]', 'output-line');
        printLine('[CONNECTING TO ERRORDON NETWORK...]', 'output-line');
        setTimeout(() => {
            printLine('[DECRYPTING AUTHENTICATION LAYER...]', 'output-line');
            setTimeout(() => {
                printLine('[ACCESS GRANTED - ENTERING THE MATRIX...]', 'output-line');
                // Set session flag for bot protection, then redirect to home
                fetch('/matrix/pass', { method: 'POST', credentials: 'same-origin' })
                    .then(() => { window.location.href = '/'; })
                    .catch(() => { window.location.href = '/'; });
            }, 800);
        }, 800);
        return;
    }
    
    // About Errordon
    if (cmd === 'about') {
        printLine('', 'output-line');
        printLine('ERRORDON - A Safe Fediverse Instance', 'output-line');
        printLine('=====================================', 'output-line');
        printLine('', 'output-line');
        printLine('🛡️  AI-Powered Content Moderation (NSFW-Protect)', 'output-line');
        printLine('🚫  Zero Tolerance: No Porn, No Hate, No Fascism', 'output-line');
        printLine('🌐  Fediverse Compatible (ActivityPub)', 'output-line');
        printLine('📊  Dynamic Storage Quotas', 'output-line');
        printLine('🎨  Matrix Theme', 'output-line');
        printLine('', 'output-line');
        printLine('Type "enter matrix" to join the network.', 'output-line');
        return;
    }
    
    // Clear
    if (cmd === 'clear') {
        output.innerHTML = '';
        return;
    }
    
    // Help
    if (cmd === 'help') {
        printLine('', 'output-line');
        printLine('╔═══════════════════════════════════════════════════════╗', 'output-line');
        printLine('║              ERRORDON TERMINAL COMMANDS               ║', 'output-line');
        printLine('╠═══════════════════════════════════════════════════════╣', 'output-line');
        printLine('║  enter matrix  - 🔓 Access Errordon Social Network    ║', 'output-line');
        printLine('║  about         - ℹ️  About Errordon                    ║', 'output-line');
        printLine('╠═══════════════════════════════════════════════════════╣', 'output-line');
        printLine('║  tetris        - 🎮 Play Tetris game                  ║', 'output-line');
        printLine('║  talk <name>   - 💬 Chat with Matrix characters       ║', 'output-line');
        printLine('║  quote         - 📜 Random Matrix quote               ║', 'output-line');
        printLine('║  hack          - 💻 Hack simulation                   ║', 'output-line');
        printLine('╠═══════════════════════════════════════════════════════╣', 'output-line');
        printLine('║  rain          - 🌧️  Toggle Matrix rain               ║', 'output-line');
        printLine('║  clear         - 🧹 Clear screen                      ║', 'output-line');
        printLine('║  date          - 📅 Show date/time                    ║', 'output-line');
        printLine('║  whoami        - 👤 Show current user                 ║', 'output-line');
        printLine('╚═══════════════════════════════════════════════════════╝', 'output-line');
        printLine('', 'output-line');
        return;
    }
    
    // Rain
    if (cmd === 'rain') {
        rainActive = !rainActive;
        if (rainActive) {
            printLine('Matrix rain enabled', 'output-line');
        } else {
            matrixCtx.fillStyle = '#000';
            matrixCtx.fillRect(0, 0, matrixCanvas.width, matrixCanvas.height);
            printLine('Matrix rain disabled', 'output-line');
        }
        return;
    }
    
    // Date
    if (cmd === 'date') {
        printLine(new Date().toString(), 'output-line');
        return;
    }
    
    // Whoami
    if (cmd === 'whoami') {
        printLine(username, 'output-line');
        return;
    }
    
    // Echo
    if (cmd === 'echo') {
        printLine(args.join(' '), 'output-line');
        return;
    }
    
    // Quote
    if (cmd === 'quote') {
        showQuote();
        return;
    }
    
    // Hack
    if (cmd === 'hack') {
        hackMatrix();
        return;
    }
    
    // Talk
    if (cmd === 'talk') {
        if (args.length === 0) {
            printLine('Usage: talk <character>', 'output-line');
            printLine('Available: neo, trinity, morpheus, smith, oracle', 'output-line');
        } else {
            startTalk(args[0].toLowerCase());
        }
        return;
    }
    
    // Tetris
    if (cmd === 'tetris') {
        printLine('Loading Tetris...', 'output-line');
        // Open Tetris in overlay iframe
        const overlay = document.getElementById('tetrisOverlay');
        const iframe = document.getElementById('tetrisFrame');
        if (overlay && iframe) {
            iframe.src = `/matrix/tetris.html?user=${encodeURIComponent(username)}`;
            overlay.style.display = 'block';
            printLine('Tetris opened! Press ESC or click RETURN TO CHAT to exit.', 'output-line');
        } else {
            printLine('Error: Tetris overlay not found', 'error-line');
        }
        return;
    }
    
    // Exit
    if (cmd === 'exit' || cmd === 'bye') {
        printLine('Goodbye! Type "clear" to clear screen.', 'output-line');
        return;
    }
    
    // Unknown
    printLine(`Unknown command: ${cmd}`, 'error-line');
    printLine('Type "help" for available commands', 'output-line');
}

// Quote function (from original matrixshell-web)
const quotes = [
    "There is no spoon.",
    "You take the red pill — you stay in Wonderland.",
    "I know kung fu.",
    "Welcome to the real world.",
    "Unfortunately, no one can be told what the Matrix is. You have to see it for yourself.",
    "Welcome to the desert of the real.",
    "I can only show you the door. You're the one that has to walk through it.",
    "Fate, it seems, is not without a sense of irony.",
    "Neo, sooner or later you're going to realize just as I did that there's a difference between knowing the path and walking the path.",
    "I'm trying to free your mind, Neo. But I can only show you the truth.",
    "Don't think you are. Know you are.",
    "To deny our own impulses is to deny the very thing that makes us human.",
    "Never send a human to do a machine's job.",
    "Hope. It is the quintessential human delusion, simultaneously the source of your greatest strength and your greatest weakness.",
    "The Matrix is a system, Neo. That system is our enemy.",
    "Choice is an illusion created between those with power and those without.",
    "Free your mind.",
    "He's beginning to believe!",
    "Follow the white rabbit!",
    "The Matrix has you Neo."
];

function showQuote() {
    const index = Math.floor(Math.random() * quotes.length);
    printLine(quotes[index], 'output-line');
}

// Hack simulation (from original matrixshell-web)
function hackMatrix() {
    const messages = [
        "[ACCESSING MAINFRAME...]",
        "[ENCRYPTION BYPASS INITIATED...]",
        "[CRYPTO-BARRIER BREACHED]",
        "[LOGGING IN AS ROOT...]",
        "[KEYSTREAM ALIGNMENT: OK]",
        "[TRACING SOURCE... REDIRECTED]",
        "[KERNEL PATCH ACCEPTED]",
        "[DATA LINK ESTABLISHED]",
        "[TRINITY: 'I'm inside.']",
        "[DOWNLOADING MATRIX CORE...]",
        "[MISSION COMPLETE. MATRIX DESTABILIZED]"
    ];
    
    let stage = 0;
    let percent = 0;
    printLine('[HACKING MATRIX...]', 'output-line');
    
    const showProgress = () => {
        if (percent >= 100) {
            clearInterval(progressInterval);
            printLine('[UPLOADING COMPLETE]', 'output-line');
            printLine('[ACCESS GRANTED]', 'output-line');
            return;
        }
        percent += Math.floor(Math.random() * 20) + 5;
        if (percent > 100) percent = 100;
        const bars = Math.floor(percent / 10);
        printLine(`[UPLOADING VIRUS ${"#".repeat(bars)}${" ".repeat(10 - bars)}] ${percent}%`, 'output-line');
    };
    
    const initialInterval = setInterval(() => {
        if (stage < messages.length) {
            printLine(messages[stage++], 'output-line');
        } else {
            clearInterval(initialInterval);
            progressInterval = setInterval(showProgress, 400);
        }
    }, 500);
    
    let progressInterval;
}

// Talk system (from original matrixshell-web with dialog trees)
let talkDB = {};
let currentTalkNode = null;
let currentTalkTree = null;

// Load talk databases
fetch('talk_db_neo.json').then(r => r.json()).then(d => talkDB.neo = d).catch(() => {});
fetch('talk_db_trinity.json').then(r => r.json()).then(d => talkDB.trinity = d).catch(() => {});
fetch('talk_db_morpheus.json').then(r => r.json()).then(d => talkDB.morpheus = d).catch(() => {});
fetch('talk_db_smith.json').then(r => r.json()).then(d => talkDB.smith = d).catch(() => {});
fetch('talk_db_orakel.json').then(r => r.json()).then(d => talkDB.oracle = d).catch(() => {});

function startTalk(character) {
    const validChars = ['neo', 'trinity', 'morpheus', 'smith', 'oracle'];
    if (!validChars.includes(character)) {
        printLine(`Unknown character: ${character}`, 'error-line');
        printLine('Available: neo, trinity, morpheus, smith, oracle', 'output-line');
        return;
    }
    
    const tree = talkDB[character];
    if (!tree) {
        printLine(`Loading ${character}'s dialog... Try again in a moment.`, 'output-line');
        return;
    }
    
    talkMode = character;
    currentTalkTree = tree;
    currentTalkNode = Object.keys(tree)[0];
    
    printLine(`Connecting to ${character}...`, 'output-line');
    printLine('', 'output-line');
    
    showTalkNode();
}

function showTalkNode() {
    const node = currentTalkTree[currentTalkNode];
    if (!node) {
        printLine('…end of dialog.', 'output-line');
        talkMode = null;
        return;
    }
    
    printLine(`${node.speaker}: ${node.text}`, 'output-line');
    
    const opts = node.options || {};
    const keys = Object.keys(opts);
    
    if (keys.length === 0) {
        printLine('Conversation ended. (type help for other commands)', 'output-line');
        talkMode = null;
        return;
    }
    
    for (let k of keys) {
        printLine(`  [${k}] ${opts[k].text}`, 'output-line');
    }
}

function handleTalkInput(input) {
    const node = currentTalkTree[currentTalkNode];
    const opts = node.options || {};
    const choice = input.trim();
    const opt = opts[choice];
    
    if (!opt) {
        printLine('Invalid choice—please select one of the numbers above.', 'error-line');
        return;
    }
    
    if (opt.next === null) {
        printLine('Conversation ended. (type help for other commands)', 'output-line');
        talkMode = null;
    } else {
        currentTalkNode = opt.next;
        showTalkNode();
    }
}
