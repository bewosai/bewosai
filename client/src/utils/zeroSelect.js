// Clicking into a number box that still holds 0 (or 0.00) selects that 0, so
// the first digit typed replaces it instead of producing "05". One document-
// level listener covers every number input on every page.

const isZeroNumberInput = (el) =>
  el instanceof HTMLInputElement &&
  (el.type === "number" || el.inputMode === "decimal" || el.inputMode === "numeric") &&
  el.value.trim() !== "" &&
  Number(el.value.replace(/,/g, "")) === 0;

export function installZeroSelect() {
  document.addEventListener("focusin", (e) => {
    const el = e.target;
    if (!isZeroNumberInput(el)) return;
    el.select();
    // The click's own mouseup would otherwise drop the selection again.
    const keep = (ev) => ev.preventDefault();
    el.addEventListener("mouseup", keep, { once: true });
    el.addEventListener("blur", () => el.removeEventListener("mouseup", keep), { once: true });
  });
}
