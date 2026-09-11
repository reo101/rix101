#pragma once
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <string>
#include <cstring>
static const char *WEB_HTML = R"HTML(
<!doctype html><html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>LiveHaptics</title><style>
body{background:#1e1e20;color:#f0f0f0;font-family:system-ui;margin:0}
header{display:flex;justify-content:space-between;align-items:center;padding:14px 20px;background:#26262a}
h1{font-size:18px;margin:0}#conn{color:#50c878}
.wrap{display:flex;gap:16px;padding:16px;flex-wrap:wrap}
.card{background:#28282c;border-radius:10px;padding:16px;flex:1;min-width:280px}
h3{margin:0 0 8px}label{display:block;margin:10px 0 4px;color:#bbb}
input[type=range]{width:100%}
button{background:#0078d7;color:#fff;border:0;border-radius:6px;padding:8px 14px;margin:4px 6px 4px 0;cursor:pointer}
button.pre{background:#3a3a40}
.meter{height:14px;background:#3a3a40;border-radius:4px;margin:6px 0}
.meter>div{height:100%;background:#50c878;border-radius:4px;width:0%}
#bar{padding:10px 20px;color:#999}</style></head><body>
<header><h1>LiveHaptics</h1><span id=conn>o Disconnected</span></header>
<div class=wrap>
<div class=card><h3>Presets</h3>
<button class=pre onclick="pre(2,0.17,16)">Music</button>
<button class=pre onclick="pre(2.5,0.25,10)">Game</button>
<button class=pre onclick="pre(3,0.3,14)">Movie</button>
<label>Gain</label><input type=range id=g min=0 max=5 step=0.1 value=2>
<label>Bass</label><input type=range id=b min=0 max=0.5 step=0.01 value=0.17>
<label>Latency cap</label><input type=range id=c min=0 max=32 step=1 value=16></div>
<div class=card><h3>Haptics Tester</h3>
<div class=meter><div id=ml></div></div>
<div class=meter><div id=mr></div></div>
<p id=info></p></div></div>
<div id=bar>Starting...</div>
<script>
const g_=g,b_=b,c_=c;
function pre(x,y,z){g_.value=x;b_.value=y;c_.value=z;send();}
function send(){fetch('/set?g='+g_.value+'&b='+b_.value+'&c='+c_.value);}
[g_,b_,c_].forEach(e=>e.oninput=send);
setInterval(()=>{fetch('/stat').then(r=>r.json()).then(j=>{
ml.style.width=(j.l/32768*100)+'%';mr.style.width=(j.r/32768*100)+'%';
conn.textContent='* Connected';
info.textContent='PID '+j.pid.toString(16)+' - '+j.pkts+' pkts - '+j.mode;
bar.textContent='Streaming active - '+j.mode+' - PID '+j.pid.toString(16);
}).catch(()=>{conn.textContent='o Disconnected';});},200);
</script></body></html>
)HTML";
static void web_send(int fd, const char *st, const char *ct, const std::string &body) {
  std::string h = std::string("HTTP/1.1 ") + st + "\r\nContent-Type: " + ct +
    "\r\nContent-Length: " + std::to_string(body.size()) + "\r\nConnection: close\r\n\r\n";
  ::send(fd, h.data(), h.size(), 0);
  ::send(fd, body.data(), body.size(), 0);
}
static void web_server() {
  int s = socket(AF_INET, SOCK_STREAM, 0);
  int one = 1; setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
  sockaddr_in a{}; a.sin_family = AF_INET; a.sin_addr.s_addr = INADDR_ANY; a.sin_port = htons(8080);
  if (bind(s, (sockaddr *)&a, sizeof(a)) < 0 || listen(s, 8) < 0) { printf("web UI: port 8080 busy\n"); return; }
  printf("Web UI ready: open http://localhost:8080\n");
  while (running.load()) {
    int c = accept(s, nullptr, nullptr);
    if (c < 0) continue;
    char buf[2048] = {0};
    recv(c, buf, sizeof(buf) - 1, 0);
    std::string req(buf);
    if (req.find("GET /stat") != std::string::npos) {
      char j[256];
      snprintf(j, sizeof(j), "{\"l\":%d,\"r\":%d,\"pkts\":%llu,\"mode\":\"%s\",\"pid\":%u}",
        g_lvlL.load(), g_lvlR.load(), (unsigned long long)g_sent.load(),
        g_bit16 ? "16bit8k" : (g_rate == 4000 ? "ulaw4k" : "ulaw8k"),
        g_pids.empty() ? 0 : (unsigned)g_pids[0]);
      web_send(c, "200 OK", "application/json", j);
    } else if (req.find("GET /set") != std::string::npos) {
      auto getp = [&](const char *k) { double v = -1; const char *p = strstr(req.c_str(), k); if (p) sscanf(p, "%*[^=]=%lf", &v); return v; };
      double g = getp("g="), b = getp("b="), cc = getp("c=");
      if (g >= 0) g_gain = g;
      if (b >= 0) g_bass = b;
      if (cc >= 0) g_cap = (int)cc;
      web_send(c, "200 OK", "text/plain", "ok");
    } else web_send(c, "200 OK", "text/html", WEB_HTML);
    close(c);
  }
}
