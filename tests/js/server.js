"use strict";

// Minimal static test server: serves the real inst/extdata/quiz/* assets
// (so tests exercise the exact shipped quiz.js/quiz.css) under /quiz/, and
// generates a fixture page for any other path from fixtures.js.

const http = require("http");
const fs = require("fs");
const path = require("path");
const { renderPage } = require("./fixtures");

const QUIZ_DIR = path.join(__dirname, "..", "..", "inst", "extdata", "quiz");
const PORT = Number(process.env.PORT || 4321);

const MIME = {
  ".js": "application/javascript",
  ".css": "text/css"
};

const server = http.createServer((req, res) => {
  const url = req.url.split("?")[0];

  if (url.indexOf("/quiz/") === 0) {
    const filePath = path.join(QUIZ_DIR, url.slice("/quiz/".length));
    if (filePath.indexOf(QUIZ_DIR) !== 0) {
      res.writeHead(403);
      res.end("Forbidden");
      return;
    }
    fs.readFile(filePath, function (err, data) {
      if (err) {
        res.writeHead(404);
        res.end("Not found: " + filePath);
        return;
      }
      res.writeHead(200, { "Content-Type": MIME[path.extname(filePath)] || "application/octet-stream" });
      res.end(data);
    });
    return;
  }

  const name = url.replace(/^\//, "").replace(/\/$/, "");
  const html = renderPage(name);
  if (!html) {
    res.writeHead(404);
    res.end("Unknown fixture: " + name);
    return;
  }
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(html);
});

server.listen(PORT, function () {
  console.log("Quiz test server listening on http://localhost:" + PORT);
});
