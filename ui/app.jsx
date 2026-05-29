const { useEffect, useRef, useState } = React;

function Icon({ name }) {
  return <i data-lucide={name}></i>;
}

function normalizeMarkdown(markdown) {
  return markdown
    .replace(/^\*\*(Contexte|Analyse|Recommandations?)\*\*\s*$/gim, "### $1")
    .replace(/^\*\*(Context|Analysis|Recommendations?)\*\*\s*$/gim, "### $1");
}

function escapeHtml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function renderMarkdown(markdown) {
  const normalized = normalizeMarkdown(markdown);
  if (!window.marked) return escapeHtml(normalized).replace(/\n/g, "<br>");

  window.marked.setOptions({
    breaks: true,
    gfm: true,
  });

  const html = window.marked.parse(normalized);
  return window.DOMPurify ? window.DOMPurify.sanitize(html) : html;
}

function AnswerBody({ busy, error, answer }) {
  if (busy || error) {
    return <p className="answer-text">{busy ? "Analyzing Air CI data..." : error}</p>;
  }

  return (
    <div
      className="markdown-answer"
      dangerouslySetInnerHTML={{ __html: renderMarkdown(answer) }}
    />
  );
}

async function askCopilot(question) {
  const response = await fetch("/api/ask", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ question }),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "Request failed");
  return data.answer || JSON.stringify(data, null, 2);
}

function App() {
  const [question, setQuestion] = useState("Which routes deserve more budget next quarter?");
  const [answer, setAnswer] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const inputRef = useRef(null);

  useEffect(() => {
    lucide.createIcons();
  });

  async function submit(value = question) {
    const text = value.trim();
    if (!text || busy) return;

    setBusy(true);
    setError("");
    setAnswer("");

    try {
      const result = await askCopilot(text);
      setAnswer(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="copilot-page">
      <div className="ambient ambient-left"></div>
      <div className="ambient ambient-right"></div>
      <div className="ambient ambient-bottom"></div>

      <section className="hero-shell">
        <header className="hero-title">
          <img src="/image/air-cote-d-ivoire-logo-circular.png" alt="" />
          <h1>Air Côte d’Ivoire Analytics AI</h1>
        </header>

        <div className="copilot-card">
          <h2>Your Agentic AI for airline decisions</h2>

          <div className={busy ? "composer is-busy" : "composer"}>
            <input
              ref={inputRef}
              value={question}
              placeholder="Ask about routes, customers, revenue, budget or quality signals"
              maxLength="500"
              onChange={(event) => setQuestion(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  submit();
                }
              }}
            />
            <button className="send-button" title="Send" onClick={() => submit()} disabled={busy}>
              <Icon name={busy ? "loader-circle" : "send-horizontal"} />
            </button>
          </div>

          {(answer || error || busy) && (
            <article className="answer-panel">
              <div className="answer-head">
                <span>{busy ? "Thinking" : error ? "Error" : "Answer"}</span>
                <Icon name={busy ? "loader-circle" : error ? "circle-alert" : "check-circle-2"} />
              </div>
              <AnswerBody busy={busy} error={error} answer={answer} />
            </article>
          )}
        </div>
      </section>
    </main>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
