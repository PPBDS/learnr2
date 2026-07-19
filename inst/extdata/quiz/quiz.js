(function () {
  "use strict";

  function decodeBase64Json(value) {
    var binary = atob(value);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    var json = new TextDecoder("utf-8").decode(bytes);
    return JSON.parse(json);
  }

  function shuffle(array) {
    var result = array.slice();
    for (var i = result.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
    }
    return result;
  }

  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    attrs = attrs || {};
    Object.keys(attrs).forEach(function (key) {
      if (key === "class") {
        node.className = attrs[key];
      } else if (key === "text") {
        node.textContent = attrs[key];
      } else {
        node.setAttribute(key, attrs[key]);
      }
    });
    (children || []).forEach(function (child) {
      node.appendChild(child);
    });
    return node;
  }

  function normalizeText(value) {
    return String(value).trim().replace(/\s+/g, " ").toLowerCase();
  }

  // ---- Progress persistence -------------------------------------------
  // Mirrors the storage-key convention used by quarto-live's own exercise
  // editor persistence (`editor-${location.href}#${id}`), with our own
  // prefix so the two never collide.

  function storageKey(data) {
    return "learnr2-question-" + window.location.href + "#" + data.id;
  }

  function loadState(data) {
    try {
      var raw = window.localStorage.getItem(storageKey(data));
      return raw ? JSON.parse(raw) : null;
    } catch (e) {
      return null;
    }
  }

  function saveState(data, state) {
    try {
      window.localStorage.setItem(storageKey(data), JSON.stringify(state));
    } catch (e) {
      // localStorage unavailable (e.g. private browsing) -- degrade silently.
    }
  }

  function clearState(data) {
    try {
      window.localStorage.removeItem(storageKey(data));
    } catch (e) {
      // Ignore.
    }
  }

  function buildChoiceQuestion(container, data) {
    var inputType = data.type === "multiple" ? "checkbox" : "radio";
    var answers = data.randomAnswerOrder ? shuffle(data.answers) : data.answers;
    var name = data.id + "-choice";

    var list = el("div", { class: "learnr2-answers" });
    answers.forEach(function (answer, index) {
      var inputId = data.id + "-answer-" + index;
      var input = el("input", { type: inputType, id: inputId, name: name });
      input.value = String(index);
      var label = el(
        "label",
        { class: "learnr2-answer", for: inputId },
        [input, el("span", { text: answer.text })]
      );
      list.appendChild(el("div", { class: "learnr2-answer-row" }, [label]));
    });

    var feedback = el("div", { class: "learnr2-feedback d-none" });
    var submit = el("button", { type: "button", class: "learnr2-submit", text: data.submitLabel });
    var tryAgain = el(
      "button",
      { type: "button", class: "learnr2-try-again d-none", text: data.tryAgainLabel }
    );

    function setFeedback(correct, message) {
      feedback.className = "learnr2-feedback " +
        (correct ? "learnr2-feedback-correct" : "learnr2-feedback-incorrect");
      feedback.textContent = message;
    }

    // Shared by a fresh submission and by restoring a saved answer, so both
    // paths produce identical feedback/disabled state.
    function applyOutcome(chosen, disable) {
      var totalCorrect = answers.filter(function (a) { return a.correct; }).length;
      var allCorrect = chosen.length === totalCorrect &&
        chosen.every(function (a) { return a.correct; });

      var message = allCorrect ? data.correctMessage : data.incorrectMessage;
      var extra = chosen.map(function (a) { return a.message; }).filter(Boolean);
      if (extra.length > 0) {
        message = message + " " + extra.join(" ");
      }
      setFeedback(allCorrect, message);

      if (disable) {
        list.querySelectorAll("input").forEach(function (input) {
          input.disabled = true;
        });
        submit.classList.add("d-none");
        if (!allCorrect && data.allowRetry) {
          tryAgain.classList.remove("d-none");
        }
      }
      return allCorrect;
    }

    submit.addEventListener("click", function () {
      var checked = Array.prototype.slice.call(list.querySelectorAll("input:checked"));
      if (checked.length === 0) {
        setFeedback(false, "Please select an answer.");
        return;
      }

      var chosen = checked.map(function (input) {
        return answers[Number(input.value)];
      });
      var allCorrect = applyOutcome(chosen, true);
      saveState(data, {
        selected: chosen.map(function (a) { return a.text; }),
        correct: allCorrect
      });
    });

    tryAgain.addEventListener("click", function () {
      list.querySelectorAll("input").forEach(function (input) {
        input.checked = false;
        input.disabled = false;
      });
      feedback.className = "learnr2-feedback d-none";
      feedback.textContent = "";
      submit.classList.remove("d-none");
      tryAgain.classList.add("d-none");
      clearState(data);
    });

    container.appendChild(list);
    container.appendChild(el("div", { class: "learnr2-controls" }, [submit, tryAgain]));
    container.appendChild(feedback);

    var saved = loadState(data);
    if (saved && Array.isArray(saved.selected)) {
      var selectedTexts = saved.selected;
      list.querySelectorAll("input").forEach(function (input) {
        var a = answers[Number(input.value)];
        if (selectedTexts.indexOf(a.text) !== -1) {
          input.checked = true;
        }
      });
      var chosen = answers.filter(function (a) { return selectedTexts.indexOf(a.text) !== -1; });
      applyOutcome(chosen, true);
    }
  }

  function buildTextQuestion(container, data) {
    var input = el("input", { type: "text", class: "learnr2-text-input" });
    var feedback = el("div", { class: "learnr2-feedback d-none" });
    var submit = el("button", { type: "button", class: "learnr2-submit", text: data.submitLabel });
    var tryAgain = el(
      "button",
      { type: "button", class: "learnr2-try-again d-none", text: data.tryAgainLabel }
    );

    function applyOutcome(value, disable) {
      var normalized = normalizeText(value);
      var match = data.answers.find(function (a) { return normalizeText(a.text) === normalized; });
      var correct = !!(match && match.correct);

      var message = correct ? data.correctMessage : data.incorrectMessage;
      if (match && match.message) {
        message = message + " " + match.message;
      }
      feedback.className = "learnr2-feedback " +
        (correct ? "learnr2-feedback-correct" : "learnr2-feedback-incorrect");
      feedback.textContent = message;

      if (disable) {
        input.disabled = true;
        submit.classList.add("d-none");
        if (!correct && data.allowRetry) {
          tryAgain.classList.remove("d-none");
        }
      }
      return correct;
    }

    submit.addEventListener("click", function () {
      var correct = applyOutcome(input.value, true);
      saveState(data, { value: input.value, correct: correct });
    });

    tryAgain.addEventListener("click", function () {
      input.value = "";
      input.disabled = false;
      feedback.className = "learnr2-feedback d-none";
      feedback.textContent = "";
      submit.classList.remove("d-none");
      tryAgain.classList.add("d-none");
      clearState(data);
    });

    container.appendChild(el("div", { class: "learnr2-answers" }, [input]));
    container.appendChild(el("div", { class: "learnr2-controls" }, [submit, tryAgain]));
    container.appendChild(feedback);

    var saved = loadState(data);
    if (saved && typeof saved.value === "string") {
      input.value = saved.value;
      applyOutcome(saved.value, true);
    }
  }

  // A box showing the pasted image, plus a *secondary* paste target of its
  // own -- but the primary way readers paste is directly into the response
  // textarea (see wireImagePaste below). A <textarea> reliably fires native
  // "paste" events in every browser; an arbitrary non-editable <div> does
  // not always, and even where it does, a reader who never notices the
  // small box below the textarea will naturally paste into the textarea
  // instead and see nothing happen. Handling paste on the textarea too
  // means it works wherever the reader's cursor actually is.
  //
  // Only image/png clipboard items are accepted, capped at MAX_BYTES so a
  // handful of screenshots can't blow past the browser's localStorage quota
  // (pasted images are persisted as base64 data URLs, like everything else).
  function buildImagePasteArea() {
    var MAX_BYTES = 2 * 1024 * 1024;
    var wrapper = el("div", { class: "learnr2-image-paste", tabindex: "0" });
    var placeholder = el("div", {
      class: "learnr2-image-paste-placeholder",
      text: "Paste a screenshot (PNG) with Ctrl+V (or Cmd+V) into the text box " +
        "above, or click here and paste it directly."
    });
    var preview = el("img", { class: "learnr2-image-paste-preview d-none" });
    var error = el("div", { class: "learnr2-image-paste-error d-none" });
    var remove = el(
      "button",
      { type: "button", class: "learnr2-image-paste-remove d-none", text: "Remove image" }
    );

    var dataUrl = null;
    var disabled = false;

    function setError(message) {
      error.textContent = message;
      error.classList.remove("d-none");
    }

    function clearError() {
      error.textContent = "";
      error.classList.add("d-none");
    }

    function setImage(nextDataUrl) {
      dataUrl = nextDataUrl;
      preview.src = nextDataUrl;
      preview.classList.remove("d-none");
      placeholder.classList.add("d-none");
      if (!disabled) {
        remove.classList.remove("d-none");
      }
      clearError();
    }

    function clearImage() {
      dataUrl = null;
      preview.src = "";
      preview.classList.add("d-none");
      placeholder.classList.remove("d-none");
      remove.classList.add("d-none");
    }

    // `silent`: when handling paste on the textarea (which is also used for
    // ordinary typed/pasted text), a clipboard paste with no image should
    // just fall through to the browser's normal text-paste behavior --
    // no error, no preventDefault(). The dedicated box has no other
    // purpose, so there `silent` is false and a non-image paste is an error.
    function handlePaste(event, silent) {
      if (disabled) {
        return;
      }
      var items = (event.clipboardData && event.clipboardData.items) || [];
      var imageItem = null;
      for (var i = 0; i < items.length; i++) {
        if (items[i].type === "image/png") {
          imageItem = items[i];
          break;
        }
      }
      if (!imageItem) {
        if (!silent) {
          setError("Please paste a PNG image (copy a screenshot, then press Ctrl+V here).");
        }
        return;
      }
      event.preventDefault();

      var file = imageItem.getAsFile();
      if (!file) {
        setError("Could not read the pasted image. Please try again.");
        return;
      }
      if (file.size > MAX_BYTES) {
        setError("That image is too large (max 2MB). Try a smaller screenshot or crop it first.");
        return;
      }

      var reader = new FileReader();
      reader.onload = function () {
        setImage(reader.result);
      };
      reader.onerror = function () {
        setError("Could not read the pasted image. Please try again.");
      };
      reader.readAsDataURL(file);
    }

    wrapper.addEventListener("paste", function (event) {
      handlePaste(event, false);
    });

    remove.addEventListener("click", function () {
      clearImage();
    });

    wrapper.appendChild(placeholder);
    wrapper.appendChild(preview);
    wrapper.appendChild(remove);
    wrapper.appendChild(error);

    return {
      element: wrapper,
      getDataUrl: function () { return dataUrl; },
      setImage: setImage,
      handlePaste: function (event) { handlePaste(event, true); },
      setDisabled: function (isDisabled) {
        disabled = isDisabled;
        wrapper.classList.toggle("learnr2-image-paste-disabled", disabled);
        wrapper.tabIndex = disabled ? -1 : 0;
        if (disabled) {
          remove.classList.add("d-none");
        } else if (dataUrl) {
          remove.classList.remove("d-none");
        }
      }
    };
  }

  // Ungraded free-response: reveals the `correct`-marked answer(s) as a
  // model answer after submitting. `type === "reflection"` locks the
  // reader's own response afterward; `"reflection_editable"` leaves it open
  // so they can keep revising it.
  function buildReflectionQuestion(container, data) {
    var editable = data.type === "reflection_editable";
    var modelAnswers = data.answers
      .filter(function (a) { return a.correct; })
      .map(function (a) { return a.text; });

    var textarea = el("textarea", { class: "learnr2-text-input learnr2-textarea", rows: "4" });
    var reveal = el("div", { class: "learnr2-model-answer d-none" });
    var submit = el("button", { type: "button", class: "learnr2-submit", text: data.submitLabel });
    var imagePaste = data.allowImage ? buildImagePasteArea() : null;
    if (imagePaste) {
      textarea.addEventListener("paste", function (event) {
        imagePaste.handlePaste(event);
      });
    }

    function showModelAnswer() {
      reveal.textContent = "";
      reveal.appendChild(el("div", { class: "learnr2-model-answer-label", text: "Model answer:" }));
      modelAnswers.forEach(function (text) {
        reveal.appendChild(el("p", { text: text }));
      });
      reveal.classList.remove("d-none");
    }

    function applyOutcome(disable) {
      showModelAnswer();
      if (disable) {
        textarea.disabled = true;
        submit.classList.add("d-none");
        if (imagePaste) {
          imagePaste.setDisabled(true);
        }
      }
    }

    submit.addEventListener("click", function () {
      applyOutcome(!editable);
      saveState(data, {
        value: textarea.value,
        image: imagePaste ? imagePaste.getDataUrl() : null,
        submitted: true
      });
    });

    container.appendChild(el("div", { class: "learnr2-answers" }, [textarea]));
    if (imagePaste) {
      container.appendChild(imagePaste.element);
    }
    container.appendChild(el("div", { class: "learnr2-controls" }, [submit]));
    container.appendChild(reveal);

    var saved = loadState(data);
    if (saved) {
      if (typeof saved.value === "string") {
        textarea.value = saved.value;
      }
      if (saved.image && imagePaste) {
        imagePaste.setImage(saved.image);
      }
      if (saved.submitted) {
        applyOutcome(!editable);
      }
    }
  }

  function renderQuestion(node) {
    var encoded = node.getAttribute("data-learnr2-question");
    if (!encoded) {
      return;
    }
    var data = decodeBase64Json(encoded);

    node.textContent = "";
    node.classList.add("learnr2-question-rendered");
    node.appendChild(el("div", { class: "learnr2-question-text", text: data.text }));

    if (data.type === "text") {
      buildTextQuestion(node, data);
    } else if (data.type === "reflection" || data.type === "reflection_editable") {
      buildReflectionQuestion(node, data);
    } else {
      buildChoiceQuestion(node, data);
    }

    node.setAttribute("data-learnr2-initialized", "true");
  }

  function init() {
    document
      .querySelectorAll(".learnr2-question:not([data-learnr2-initialized])")
      .forEach(renderQuestion);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
