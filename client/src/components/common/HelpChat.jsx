import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { MessageCircleQuestion, Send, X } from "lucide-react";
import { support as supportApi } from "../../api/index.js";

/* Floating help chat on every signed-in page. Answers how-to questions about
   Bewosai only (backend superadmin/help_guide.py); every question reaches
   Super Admin → Help Chat. Anything else → "Send feedback". */
const STARTERS = ["How do I make an invoice?", "How to add a product?", "How to record an expense?", "Where is the balance sheet?"];

export default function HelpChat({ feedbackPath = "/settings" }) {
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [messages, setMessages] = useState([
    { from: "bot", text: "Hi! Ask me how to do anything in Bewosai — sales, stock, parties, payments, expenses, reports, settings." },
  ]);
  const endRef = useRef(null);

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, open]);

  const ask = async (question) => {
    const q = question.trim();
    if (!q || busy) return;
    setInput("");
    setMessages((m) => [...m, { from: "me", text: q }]);
    setBusy(true);
    try {
      const { data } = await supportApi.ask(q);
      setMessages((m) => [...m, { from: "bot", text: data.answer, related: data.related || [] }]);
    } catch (err) {
      const text = err.response?.data?.error || err.response?.data?.detail || "Couldn't get an answer right now. Please try again.";
      setMessages((m) => [...m, { from: "bot", text }]);
    } finally {
      setBusy(false);
    }
  };

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} aria-label="Help chat"
        className="fixed bottom-5 right-5 z-40 flex h-12 w-12 items-center justify-center rounded-full bg-orange-500 text-white shadow-lg hover:bg-orange-600 print:hidden">
        <MessageCircleQuestion className="h-6 w-6" />
      </button>
    );
  }

  return (
    <div className="fixed bottom-5 right-5 z-40 flex h-112 w-[calc(100vw-2.5rem)] max-w-sm flex-col overflow-hidden rounded-2xl border border-navy-700 bg-navy-900 shadow-2xl print:hidden">
      <div className="flex items-center justify-between border-b border-navy-800 px-4 py-3">
        <p className="text-sm font-semibold text-white">Bewosai Help</p>
        <button onClick={() => setOpen(false)} aria-label="Close help" className="text-navy-400 hover:text-white"><X size={18} /></button>
      </div>
      <div className="flex-1 space-y-2 overflow-y-auto px-3 py-3 text-sm">
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.from === "me" ? "justify-end" : "justify-start"}`}>
            <div className={`max-w-[85%] rounded-xl px-3 py-2 whitespace-pre-line ${m.from === "me" ? "bg-orange-500 text-white" : "bg-navy-800 text-navy-100"}`}>
              {m.text}
              {m.related?.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-1.5">
                  <span className="w-full text-[11px] text-navy-400">Related:</span>
                  {m.related.map((r) => (
                    <button key={r} onClick={() => ask(`How to ${r}`)}
                      className="rounded-full border border-navy-600 px-2 py-0.5 text-[11px] text-navy-200 hover:border-orange-500 hover:text-white">
                      {r}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
        {messages.length === 1 && (
          <div className="flex flex-wrap gap-1.5 pt-1">
            {STARTERS.map((s) => (
              <button key={s} onClick={() => ask(s)} className="rounded-full border border-navy-700 px-2.5 py-1 text-xs text-navy-300 hover:border-orange-500 hover:text-white">{s}</button>
            ))}
          </div>
        )}
        {busy && <p className="text-xs text-navy-500">Thinking…</p>}
        <div ref={endRef} />
      </div>
      <form onSubmit={(e) => { e.preventDefault(); ask(input); }} className="flex items-center gap-2 border-t border-navy-800 px-3 py-2">
        <input value={input} onChange={(e) => setInput(e.target.value)} maxLength={500} placeholder="Ask how to use Bewosai…"
          className="flex-1 rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none" />
        <button type="submit" disabled={busy || !input.trim()} aria-label="Send"
          className="rounded-lg bg-orange-500 p-2 text-white disabled:opacity-50"><Send size={16} /></button>
      </form>
      <Link to={feedbackPath} onClick={() => setOpen(false)} className="border-t border-navy-800 px-4 py-2 text-center text-xs text-orange-400 hover:underline">
        Not answered? Send feedback to the Bewosai team
      </Link>
    </div>
  );
}
