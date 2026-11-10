"use strict";
const crypto = require("crypto");

// Mirrors canonicalSubmission() in quiz.js and canonical_submission() in
// R/submission.R; the pinned fixture below is shared with test-submission.R.
function canonicalSubmission(payload) {
  const from = payload.loadedFrom && typeof payload.loadedFrom.fingerprint === "string" ? payload.loadedFrom.fingerprint : "";
  const p = payload.progress;
  const progress = p ? [p.sections, p.of, p.answered, p.of_questions].map((v) => (v == null ? "" : String(v))).join("/") : "";
  const lines = ["learnr2-fingerprint-v1", "time=" + payload.time, "device=" + payload.metadata.deviceId, "loadedFrom=" + from, "progress=" + progress];
  Object.keys(payload.info).sort().forEach((k) => lines.push("info." + k + "=" + (payload.info[k] == null ? "" : String(payload.info[k]))));
  payload.answers.forEach((a) => {
    const v = a.answer;
    lines.push("answer." + a.id + "=" + (v == null ? "<null>" : Array.isArray(v) ? v.map(String).join("\u001f") : String(v)));
  });
  return lines.join("\n");
}
const sha256 = (text) => crypto.createHash("sha256").update(text, "utf8").digest("hex");

module.exports = { canonicalSubmission, sha256 };
