let ws = new WebSocket("ws://localhost:8081");

ws.onmessage = (event) => {
    document.getElementById("received").innerText = event.data;
};
