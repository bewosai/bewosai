"""
The in-app help chat's knowledge: short how-to answers about using Bewosai,
and a matcher that picks the best one for a question. It answers only about
the app — anything else gets a polite "I can only help with Bewosai".

To improve it, look at Super Admin → Help Chat for questions that got no
answer, and add an entry here (keywords are lower-case words or phrases the
question may contain; English and common Romanized Nepali both work).
"""
import re

GUIDE = [
    {
        "topic": "Sign in",
        "keywords": ["login", "log in", "sign in", "signin", "otp", "login code", "verification", "email code",
                     "password", "code not", "get the code", "get code", "receive code"],
        "answer": "Bewosai has no password. Enter your email on the sign-in screen and tap Send Code — a 6-digit code "
                  "arrives by email (check Spam too). Type it in to sign in. Codes last 10 minutes; tap Resend if one expires.",
    },
    {
        "topic": "New sale / invoice",
        "keywords": ["sale", "sell", "invoice", "bill", "bikri", "new invoice", "make bill", "create invoice", "pos"],
        "answer": "Go to Sales → New Invoice. Pick a customer (or leave it as Cash Sales), add items with quantity and "
                  "price, set any discount and tax, enter how much was paid and how (Cash, Bank, eSewa, Khalti or Split), "
                  "then Save. Stock goes down automatically for a confirmed invoice.",
    },
    {
        "topic": "Invoice number",
        "keywords": ["invoice number", "invoice no", "prefix", "numbering", "number repeat", "duplicate number"],
        "answer": "New invoices are numbered automatically (INV-0001, INV-0002 …). To change the start text, go to "
                  "Settings → Appearance & Invoices → Invoice Prefix. A number can never be used twice in a business.",
    },
    {
        "topic": "Print / share invoice",
        "keywords": ["print", "pdf", "share", "whatsapp", "download invoice", "send invoice"],
        "answer": "Open the invoice in Sales and tap Print / PDF to print or save it, or Share to send it on WhatsApp. "
                  "Your logo, header colour, footer, terms and warranty text come from Settings → Appearance & Invoices.",
    },
    {
        "topic": "Receive payment / due",
        "keywords": ["receive payment", "due", "baki", "udharo", "credit", "pay later", "partial", "collect", "repayment"],
        "answer": "For money still due on an invoice, open it in Sales and tap Receive Payment, or go to Payments → "
                  "Payment In and pick the customer. The payment settles the oldest unpaid invoices first and the "
                  "customer's balance updates.",
    },
    {
        "topic": "Purchase",
        "keywords": ["purchase", "buy", "kharid", "supplier bill", "stock in from supplier", "new purchase"],
        "answer": "Go to Purchases → New Purchase. Pick the supplier, add items with quantity and cost, enter what you "
                  "paid, and Save. Stock goes up automatically for a confirmed purchase.",
    },
    {
        "topic": "Returns",
        "keywords": ["return", "refund", "sales return", "purchase return", "goods back", "firta"],
        "answer": "Sales → Return (or Purchases → Return): choose the original invoice/bill, enter how many of each item "
                  "came back, and save. Stock is corrected, and the amount first reduces what is still due; only the "
                  "rest is refunded in cash or by bank.",
    },
    {
        "topic": "Quotation",
        "keywords": ["quotation", "estimate", "quote"],
        "answer": "Sales → Quotation lets you create a price quotation for a customer with an expiry date and print or "
                  "share it. It does not change stock or money.",
    },
    {
        "topic": "Add item / product",
        "keywords": ["add item", "add product", "product", "item", "saman", "service", "new item", "inventory"],
        "answer": "Go to Inventory → Add Product. Enter the name, sale and purchase price, unit and opening stock. Choose "
                  "Service for things you sell without stock (repairs, fees). You can also import many products at once "
                  "from Excel (Settings → Bulk Import, Premium).",
    },
    {
        "topic": "Stock",
        "keywords": ["stock", "low stock", "stock adjust", "damage", "lost", "stock in", "stock out", "maujdat"],
        "answer": "Inventory shows each item's stock. To correct it, use Stock → add a movement (Stock In, Stock Out, "
                  "Damage, Lost or Adjustment). Items at or below their low-stock level are listed under Low Stock.",
    },
    {
        "topic": "Units",
        "keywords": ["unit", "box", "piece", "kg", "secondary unit", "conversion"],
        "answer": "Inventory → Units: create a unit (e.g. Box) and optionally a second one (e.g. Piece) with how many "
                  "make one (12 Pieces = 1 Box). On a bill you can then sell in either unit; stock is kept in the main unit.",
    },
    {
        "topic": "Customers & suppliers",
        "keywords": ["party", "parties", "customer", "supplier", "grahak", "add customer", "add supplier", "ledger"],
        "answer": "Parties → Add Party: enter the name, phone and whether they are a Customer, Supplier or Both, plus any "
                  "opening balance. Tap a party to see their ledger — every invoice, payment and return with a running balance.",
    },
    {
        "topic": "Party balance",
        "keywords": ["balance", "owe", "to receive", "to give", "lena", "dena", "outstanding"],
        "answer": "A positive balance means the party owes you (To Receive); negative means you owe them (To Give). It "
                  "comes from their invoices, bills, payments and returns — open the party's ledger to see each step.",
    },
    {
        "topic": "Expense",
        "keywords": ["expense", "kharcha", "spend", "rent", "salary", "electricity", "add expense"],
        "answer": "Go to Expenses → Add Expense. Enter the amount, date, category and how it was paid. For Bank, eSewa or "
                  "Khalti pick the account it was paid from so that account's balance goes down. You can attach a receipt photo.",
    },
    {
        "topic": "Bank accounts",
        "keywords": ["bank", "account", "esewa", "khalti", "wallet", "bank statement", "cash in hand", "connect ips"],
        "answer": "Banking → Add Account for each bank or wallet with its opening balance. Sales, purchases, payments and "
                  "expenses paid that way show on its statement automatically. Reports → Bank Statement and Cash In Hand "
                  "show running balances.",
    },
    {
        "topic": "Reports",
        "keywords": ["report", "profit", "loss", "day book", "daybook", "sales report", "all transactions", "aging"],
        "answer": "Reports has Profit & Loss, Sales, Expenses, Stock, Day Book, All Transactions, Party Statement, Cash In "
                  "Hand, Bank Statement and Balance Sheet. Pick the dates at the top; most reports can be downloaded as CSV.",
    },
    {
        "topic": "Balance sheet",
        "keywords": ["balance sheet", "assets", "liabilities", "equity", "net worth", "owner capital"],
        "answer": "Reports → Balance Sheet shows what you own (cash, bank, receivables, stock) and owe (payables) on the "
                  "date you choose, plus the profit from a start date you choose. Stock for a past date is an estimate.",
    },
    {
        "topic": "Sorting & search",
        "keywords": ["sort", "order", "ascending", "descending", "alphabetical", "search", "filter", "a to z"],
        "answer": "Every list has a search box and, on the website, Sort by with an Asc/Desc button (date, amount, name …). "
                  "Customer, supplier and item names are shown A–Z.",
    },
    {
        "topic": "Staff",
        "keywords": ["staff", "employee", "cashier", "invite", "role", "permission", "add user"],
        "answer": "Settings → Staff (Premium): invite a staff member by email and choose their role (Manager, Cashier, "
                  "Viewer …) and what they may see or change. They accept the invitation from the email.",
    },
    {
        "topic": "Plan / coupon",
        "keywords": ["plan", "premium", "upgrade", "coupon", "subscription", "price", "refer", "referral", "free month"],
        "answer": "Settings → Upgrade Plan shows the plans. Type a coupon or a friend's referral code in \"Have a coupon?\" "
                  "and tap Apply once — a code can be used only one time. Refer & Win gives you and a new friend a free month.",
    },
    {
        "topic": "Business profile",
        "keywords": ["business profile", "logo", "pan", "vat", "address", "business name", "tax rate", "fiscal year"],
        "answer": "Settings → Business: name, type, address, phone, logo and default VAT %. PAN/VAT number, currency and "
                  "fiscal year are under Tax & Compliance. Close a fiscal year from Settings → Advanced.",
    },
    {
        "topic": "Several businesses",
        "keywords": ["switch business", "another business", "multiple business", "second business", "new business"],
        "answer": "Tap your business name at the top to switch between businesses or create a new one. Each business keeps "
                  "its own data.",
    },
    {
        "topic": "Delete / recycle bin",
        "keywords": ["delete", "deleted", "recycle", "restore", "undo", "trash", "remove"],
        "answer": "Deleted invoices, bills, payments, expenses and items go to the Recycle Bin, where you can Restore them "
                  "(stock and balances come back) or delete them for good.",
    },
    {
        "topic": "Delete account",
        "keywords": ["delete account", "delete my account", "close account", "close my account", "remove account",
                     "remove my account", "delete my data"],
        "answer": "App: Settings → Delete Account. Website: bewosai.com/delete-account. You confirm with a code sent to "
                  "your email; this permanently deletes your account and the businesses you own.",
    },
    {
        "topic": "Offline",
        "keywords": ["offline", "no internet", "internet", "sync", "network"],
        "answer": "Without internet the app can still save some entries (like expenses and sales) and sends them when you "
                  "are back online. Reports and other changes need a connection.",
    },
    {
        "topic": "Reminders",
        "keywords": ["reminder", "notification", "alert", "remind"],
        "answer": "When saving an invoice with money due, turn on Reminder and pick a date and time — the phone notifies you "
                  "to follow up. Allow notifications for Bewosai in your phone settings.",
    },
    {
        "topic": "Nepali date",
        "keywords": ["nepali date", "bs", "bikram sambat", "calendar", "date format", "language", "nepali"],
        "answer": "App Preferences (app) or Settings → Appearance (website) lets you show dates in Bikram Sambat and switch "
                  "the language.",
    },
    {
        "topic": "Feedback / support",
        "keywords": ["feedback", "complain", "complaint", "support", "contact", "help me", "problem", "bug", "suggest"],
        "answer": "Use \"Send feedback\" below this chat (or Settings → Support on the website). Super Admin reads every "
                  "message and the reply shows under Your messages.",
    },
]

# The answer each topic actually gives: numbered steps (where to tap, what to
# fill in) and a tip. Replaces the one-line summaries above when shown.
STEPS = {
    "Sign in": ([
        "Open Bewosai and type your email on the sign-in screen.",
        "Tap Send Code.",
        "Open your email (check Spam / Promotions too) and copy the 6-digit code.",
        "Type the code in Bewosai and tap Verify.",
    ], "A code works for 10 minutes. If it expired or never came, tap Resend after 60 seconds."),
    "New sale / invoice": ([
        "Go to Sales and tap New Invoice (app: the + New Invoice button).",
        "Choose the customer, or leave it empty for a Cash Sale.",
        "Add each item: pick the product, enter quantity and price.",
        "Add any discount or VAT.",
        "Enter the amount paid and how (Cash, Bank, eSewa, Khalti or Split).",
        "Tap Save — print or share it from the next screen.",
    ], "Stock goes down automatically when the invoice is Confirmed. Save as Draft if it isn't final yet."),
    "Invoice number": ([
        "New invoices get the next number automatically (INV-0001, INV-0002 …).",
        "To change the start text, open Settings → Appearance & Invoices.",
        "Type your Invoice Prefix (e.g. BWS-) and tap Save.",
    ], "The same invoice number can never be used twice in one business."),
    "Print / share invoice": ([
        "Open Sales and tap the invoice.",
        "Tap Print / PDF to print or save a PDF, or Share to send it on WhatsApp.",
        "To change how it looks, go to Settings → Appearance & Invoices (logo, colour, footer, terms, warranty).",
    ], "Your business logo and address come from Settings → Business."),
    "Receive payment / due": ([
        "Open Sales and tap the invoice that still has money due.",
        "Tap Receive Payment.",
        "Enter the amount received and how it was paid, then Save.",
    ], "Or go to Payments → Payment In and pick the customer — it pays their oldest unpaid invoices first."),
    "Purchase": ([
        "Go to Purchases and tap New Purchase.",
        "Choose the supplier.",
        "Add each item with quantity and cost price.",
        "Enter what you paid now and how, then Save.",
    ], "Stock goes up automatically for a confirmed purchase. Unpaid amount shows as what you owe the supplier."),
    "Returns": ([
        "Go to Sales → Return (or Purchases → Return for goods you send back).",
        "Pick the original invoice or bill.",
        "Enter how many of each item came back.",
        "Choose Cash or Bank for any refund and Save.",
    ], "The return first reduces what is still due; only the rest is paid back."),
    "Quotation": ([
        "Go to Sales → Quotation and tap New Quotation.",
        "Choose the customer, enter the amount and an expiry date.",
        "Save, then Print or Share it.",
    ], "A quotation doesn't change stock or money."),
    "Add item / product": ([
        "Go to Inventory and tap Add Product.",
        "Enter the name, sale price and purchase price.",
        "Choose the unit and enter opening stock.",
        "Choose Service instead of Product for things without stock (repairs, fees).",
        "Tap Save.",
    ], "Many products? Settings → Bulk Import Products loads them from an Excel file (Premium)."),
    "Stock": ([
        "Go to Inventory to see each item's stock.",
        "To correct it, open Stock and add a movement: Stock In, Stock Out, Damage, Lost or Adjustment.",
        "Enter the quantity and a note, then Save.",
    ], "Items at or below their low-stock level show under Low Stock."),
    "Units": ([
        "Go to Inventory → Units and tap Add Unit.",
        "Enter the main unit (e.g. Box).",
        "Optionally add a second unit (e.g. Piece) and how many make one (12).",
        "Save, then pick this unit on your products.",
    ], "On a bill you can sell in either unit; stock is always kept in the main unit."),
    "Customers & suppliers": ([
        "Go to Parties and tap Add Party.",
        "Enter the name and phone number.",
        "Choose Customer, Supplier or Both.",
        "Enter an opening balance if they already owe you (or you owe them), then Save.",
    ], "Tap a party any time to see their full ledger with a running balance."),
    "Party balance": ([
        "Go to Parties and tap the party.",
        "Positive balance = they owe you (To Receive); negative = you owe them (To Give).",
        "Open Ledger to see every invoice, payment and return that makes up the balance.",
    ], "Record money received or paid in Payments to change the balance."),
    "Expense": ([
        "Go to Expenses and tap Add Expense.",
        "Enter the amount and date, and choose a category.",
        "Choose how it was paid; for Bank, eSewa or Khalti pick the account it came from.",
        "Add a receipt photo if you like, then Save.",
    ], "Bank/wallet expenses reduce that account's balance automatically."),
    "Bank accounts": ([
        "Go to Banking and tap Add Account.",
        "Enter the account name, type (Bank, eSewa, Khalti …) and opening balance, then Save.",
        "Sales, purchases, payments and expenses paid this way show on its statement automatically.",
    ], "Reports → Bank Statement and Cash In Hand show running balances by date."),
    "Reports": ([
        "Go to Reports (app: Settings → View Report).",
        "Pick the report: Profit & Loss, Sales, Stock, Day Book, All Transactions, Party Statement, Cash In Hand, Bank Statement or Balance Sheet.",
        "Choose the date range at the top.",
        "Tap Download CSV to save it.",
    ], "Profit & Loss counts cost of goods sold and expenses, not just sales."),
    "Balance sheet": ([
        "Go to Reports → Balance Sheet.",
        "Choose the balance sheet date (what you own and owe on that day).",
        "Choose the start date for the profit line.",
        "Read Assets, Liabilities and Owner's equity — they always balance.",
    ], "Stock for a past date is an estimate, worked back from today's stock."),
    "Sorting & search": ([
        "Type in the search box at the top of any list to filter it.",
        "Tap Sort (arrow button) next to the search box.",
        "Choose what to sort by (date, amount, name …) and Ascending or Descending.",
    ], "Customer, supplier and item names are A–Z by default."),
    "Staff": ([
        "Go to Settings → Staff (Premium).",
        "Tap Invite, enter their email and choose a role (Manager, Cashier, Viewer …).",
        "Choose what they may see or change, then Send.",
        "They accept from the email and sign in with their own email code.",
    ], "You can change or remove a staff member's access any time."),
    "Plan / coupon": ([
        "Go to Settings → Upgrade Plan.",
        "Type the coupon (6 characters) or a friend's referral code (8 characters) in Have a Coupon?",
        "Tap Apply once and wait for the message.",
    ], "Each code works only one time. Share your own referral link to give a friend and you a free month."),
    "Business profile": ([
        "Go to Settings → Business.",
        "Edit name, type, address, phone, logo and default VAT %.",
        "PAN/VAT number, currency and fiscal year are under Tax & Compliance.",
        "Tap Save.",
    ], "Close a fiscal year from Settings → Advanced."),
    "Several businesses": ([
        "Tap your business name at the top.",
        "Pick another business to switch, or tap Create Business for a new one.",
    ], "Each business keeps its own data, staff and reports."),
    "Delete / recycle bin": ([
        "Deleted invoices, bills, payments, expenses and items go to the Recycle Bin.",
        "Open Recycle Bin from the menu.",
        "Tap Restore to bring one back (stock and balances come back too), or Delete forever.",
    ], "Delete forever can't be undone."),
    "Delete account": ([
        "App: Settings → Delete Account. Website: bewosai.com/delete-account.",
        "Tap Email a confirmation code.",
        "Enter the code and tap Delete my account.",
    ], "This permanently deletes your account and every business you own. Download reports first."),
    "Offline": ([
        "Without internet you can still save some entries, like expenses and sales.",
        "They are sent automatically when you're back online.",
    ], "Reports and most other changes need a connection."),
    "Reminders": ([
        "When saving an invoice with money due, turn on Reminder.",
        "Pick the date and time to follow up, then Save.",
        "Allow notifications for Bewosai in your phone's settings.",
    ], "The reminder is cancelled automatically once the invoice is paid."),
    "Nepali date": ([
        "App: Settings → App Preferences. Website: Settings → Appearance.",
        "Turn on Bikram Sambat (BS) dates, or change the language.",
    ], "Dates are stored the same either way — only how they're shown changes."),
    "Feedback / support": ([
        "App: Settings → Help & Feedback → Send feedback. Website: Settings → Support.",
        "Write a subject and your message, then Send.",
        "The Bewosai team's reply shows under Your messages.",
    ], "Describe what you tapped and what happened — it helps us fix things faster."),
}


def _format(topic, steps, tip):
    lines = [f"{topic}:"] + [f"{i}. {step}" for i, step in enumerate(steps, 1)]
    if tip:
        lines.append(f"Tip: {tip}")
    return "\n".join(lines)


for _entry in GUIDE:
    if _entry["topic"] in STEPS:
        _entry["answer"] = _format(_entry["topic"], *STEPS[_entry["topic"]])

STOP_WORDS = {
    "how", "do", "i", "to", "a", "an", "the", "in", "on", "my", "can", "is", "it", "of", "for", "what", "where",
    "please", "me", "and", "or", "with", "this", "that", "app", "bewosai", "garne", "kasari", "ho", "ma", "ko", "le",
    "cha", "chha", "kaha", "k", "want", "need", "help", "will", "does", "are", "be", "you",
}

OFF_TOPIC = ("I can only help with how to use Bewosai — sales, purchases, stock, parties, payments, expenses, banking, "
             "reports and settings. Try asking about one of those, or send your question as feedback.")


def _words(text):
    return [w for w in re.findall(r"[a-z0-9]+", text.lower()) if w not in STOP_WORDS]


def answer(question):
    """(answer text, matched topic or None, up to 3 other likely topics)."""
    text = " " + " ".join(re.findall(r"[a-z0-9]+", (question or "").lower())) + " "
    words = set(_words(question or ""))
    if not words:
        return OFF_TOPIC, None, [g["topic"] for g in GUIDE[:3]]

    scored = []
    for entry in GUIDE:
        score = 0.0
        for kw in entry["keywords"]:
            if " " in kw:
                if f" {kw} " in text:
                    score += 4                      # a whole phrase beats single words
            elif kw in words:
                score += 2
            elif len(kw) > 4 and any(w.startswith(kw[:5]) or kw.startswith(w[:5]) for w in words if len(w) > 4):
                score += 1                          # "invoices", "selling" …
        if score:
            scored.append((score, entry))
    scored.sort(key=lambda s: -s[0])
    if not scored or scored[0][0] < 2:
        return OFF_TOPIC, None, [s[1]["topic"] for s in scored[:3]]
    best = scored[0][1]
    return best["answer"], best["topic"], [s[1]["topic"] for s in scored[1:4]]
