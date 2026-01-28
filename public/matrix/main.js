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
    matrixCtx.font = fontSize + 'px monospace';
    
    for (let i = 0; i < columns; i++) {
        const text = MATRIX_CHARS.charAt(Math.floor(Math.random() * MATRIX_CHARS.length));
        const x = i * fontSize;
        const y = drops[i] * fontSize;
        
        // Occasional bright character
        matrixCtx.fillStyle = Math.random() > 0.98 ? '#fff' : '#0F0';
        matrixCtx.fillText(text, x, y);
        
        if (y > matrixCanvas.height && Math.random() > 0.975) {
            drops[i] = 0;
        }
        drops[i] += 0.3 + Math.random() * 0.4;
    }
}

setInterval(drawMatrixRain, 80); // Slower rain

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
const tetrisOverlay = document.getElementById('tetrisOverlay');
const tetrisFrame = document.getElementById('tetrisFrame');

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
    terminal.style.display = 'flex';
    promptEl.textContent = username + '@errordon:~$';
    commandInput.focus();
    
    printLine('WELCOME TO ERRORDON - A SAFE FEDIVERSE');
    printLine('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    printLine('🛡️ NO PORN • NO HATE • NO FASCISM');
    printLine('');
    printLine('Type "enter matrix" to access the social network');
    printLine('Type "help" for all available commands');
    printLine('');
    printLine('Connected as: ' + username);
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

// Event Listeners
document.getElementById('connectBtn').addEventListener('click', login);
document.getElementById('logoutBtn').addEventListener('click', logout);

// Listen for messages from Tetris iframe
window.addEventListener('message', (event) => {
    if (event.data === 'closeTetris') {
        closeTetris();
    }
});

function closeTetris() {
    tetrisOverlay.style.display = 'none';
    tetrisFrame.src = '';
    commandInput.focus();
}

document.getElementById('tetrisClose').addEventListener('click', closeTetris);

// ESC to close Tetris
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && tetrisOverlay.style.display === 'block') closeTetris();
});

// Terminal Output
function printLine(text, className) {
    const line = document.createElement('div');
    line.className = className || 'output-line';
    line.textContent = text;
    output.appendChild(line);
    output.scrollTop = output.scrollHeight;
}

// Command Input
commandInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
        const cmd = commandInput.value.trim();
        if (cmd) {
            printLine(username + '@errordon:~$ ' + cmd, 'command-line');
            
            // Talk mode active
            if (talkMode) {
                handleTalkInput(cmd);
            } else {
                handleCommand(cmd);
            }
        }
        commandInput.value = '';
    }
});

// Commands
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
    "Free your mind.",
    "The Matrix has you Neo."
];

function handleCommand(input) {
    const lower = input.toLowerCase();
    const parts = input.split(' ');
    const cmd = parts[0].toLowerCase();
    const args = parts.slice(1);

    // ENTER MATRIX
    if (lower === 'enter matrix' || lower === 'entermatrix' || lower === 'login') {
        printLine('[INITIATING NEURAL INTERFACE...]');
        // Set session flag to bypass matrix redirect
        fetch('/matrix/pass', { method: 'POST', credentials: 'same-origin' }).catch(() => {});
        setTimeout(() => {
            printLine('[CONNECTING TO ERRORDON NETWORK...]');
            setTimeout(() => {
                printLine('[ACCESS GRANTED - ENTERING THE MATRIX...]');
                setTimeout(() => { window.location.href = '/auth/sign_in'; }, 800);
            }, 600);
        }, 600);
        return;
    }

    // HELP
    if (cmd === 'help') {
        printLine('');
        printLine('ERRORDON TERMINAL COMMANDS');
        printLine('━━━━━━━━━━━━━━━━━━━━━━━━━━');
        printLine('');
        printLine('enter matrix  → Access Errordon Network');
        printLine('about         → About Errordon');
        printLine('');
        printLine('tetris        → Play Tetris');
        printLine('talk <name>   → Chat (neo/trinity/morpheus/smith/oracle)');
        printLine('quote         → Random Matrix quote');
        printLine('hack          → Hack simulation');
        printLine('rain          → Toggle Matrix rain');
        printLine('');
        printLine('clear         → Clear screen');
        printLine('date          → Show date/time');
        printLine('whoami        → Show current user');
        printLine('echo <text>   → Echo text');
        printLine('logout        → Disconnect');
        return;
    }

    // ABOUT
    if (cmd === 'about') {
        printLine('');
        printLine('ERRORDON - A Safe Fediverse Instance');
        printLine('=====================================');
        printLine('🛡️  AI-Powered Content Moderation (NSFW-Protect)');
        printLine('🚫  Zero Tolerance: No Porn, No Hate, No Fascism');
        printLine('🌐  Fediverse Compatible (ActivityPub)');
        printLine('🎨  Matrix Theme');
        printLine('');
        printLine('Type "enter matrix" to join the network.');
        return;
    }

    // RAIN
    if (cmd === 'rain') {
        rainActive = !rainActive;
        if (rainActive) {
            printLine('Matrix rain enabled');
        } else {
            matrixCtx.fillStyle = '#000';
            matrixCtx.fillRect(0, 0, matrixCanvas.width, matrixCanvas.height);
            printLine('Matrix rain disabled');
        }
        return;
    }

    // TETRIS
    if (cmd === 'tetris') {
        printLine('[LOADING TETRIS...]');
        setTimeout(() => {
            tetrisFrame.src = '/matrix/tetris.html?user=' + encodeURIComponent(username);
            tetrisOverlay.style.display = 'block';
        }, 500);
        return;
    }

    // QUOTE
    if (cmd === 'quote') {
        printLine(quotes[Math.floor(Math.random() * quotes.length)]);
        return;
    }

    // HACK
    if (cmd === 'hack') {
        const msgs = [
            "[ACCESSING MAINFRAME...]",
            "[ENCRYPTION BYPASS INITIATED...]",
            "[CRYPTO-BARRIER BREACHED]",
            "[LOGGING IN AS ROOT...]",
            "[KEYSTREAM ALIGNMENT: OK]",
            "[TRACING SOURCE... REDIRECTED]",
            "[DATA LINK ESTABLISHED]",
            "[TRINITY: 'I'm inside.']",
            "[MISSION COMPLETE]"
        ];
        let i = 0;
        const interval = setInterval(() => {
            if (i < msgs.length) { printLine(msgs[i++]); }
            else { clearInterval(interval); printLine('[ACCESS GRANTED]'); }
        }, 400);
        return;
    }

    // TALK
    if (cmd === 'talk') {
        if (args.length === 0) {
            printLine('Usage: talk <character>');
            printLine('Available: neo, trinity, morpheus, smith, oracle');
        } else {
            startTalk(args[0].toLowerCase());
        }
        return;
    }

    // CLEAR
    if (cmd === 'clear') { output.innerHTML = ''; return; }

    // DATE
    if (cmd === 'date') { printLine(new Date().toString()); return; }

    // WHOAMI
    if (cmd === 'whoami') { printLine(username); return; }

    // ECHO
    if (cmd === 'echo') { printLine(args.join(' ')); return; }

    // LOGOUT
    if (cmd === 'logout' || cmd === 'exit') { logout(); return; }

    // UNKNOWN
    printLine('Unknown command: ' + cmd, 'error-line');
    printLine('Type "help" for available commands');
}

// Talk system
let talkDB = {};
let currentTalkNode = null;
let currentTalkTree = null;

// Load talk databases
fetch('/matrix/talk_db_neo.json').then(r => r.json()).then(d => talkDB.neo = d).catch(() => {});
fetch('/matrix/talk_db_trinity.json').then(r => r.json()).then(d => talkDB.trinity = d).catch(() => {});
fetch('/matrix/talk_db_morpheus.json').then(r => r.json()).then(d => talkDB.morpheus = d).catch(() => {});
fetch('/matrix/talk_db_smith.json').then(r => r.json()).then(d => talkDB.smith = d).catch(() => {});
fetch('/matrix/talk_db_oracle.json').then(r => r.json()).then(d => talkDB.oracle = d).catch(() => {});

function startTalk(character) {
    const validChars = ['neo', 'trinity', 'morpheus', 'smith', 'oracle'];
    if (!validChars.includes(character)) {
        printLine('Unknown character: ' + character, 'error-line');
        printLine('Available: neo, trinity, morpheus, smith, oracle');
        return;
    }
    
    const tree = talkDB[character];
    if (!tree) {
        printLine('Loading ' + character + "'s dialog... Try again in a moment.");
        return;
    }
    
    talkMode = character;
    currentTalkTree = tree;
    currentTalkNode = Object.keys(tree)[0];
    
    printLine('[CONNECTING TO ' + character.toUpperCase() + '...]');
    printLine('');
    
    showTalkNode();
}

function showTalkNode() {
    const node = currentTalkTree[currentTalkNode];
    if (!node) {
        printLine('…end of dialog.');
        talkMode = null;
        return;
    }
    
    printLine(node.speaker + ': "' + node.text + '"');
    
    const opts = node.options || {};
    const keys = Object.keys(opts);
    
    if (keys.length === 0) {
        printLine('[DISCONNECTED]');
        talkMode = null;
        return;
    }
    
    for (let k of keys) {
        printLine('  [' + k + '] ' + opts[k].text);
    }
    printLine('Type a number to respond:');
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
        printLine('[DISCONNECTED]');
        talkMode = null;
    } else {
        currentTalkNode = opt.next;
        showTalkNode();
    }
}
