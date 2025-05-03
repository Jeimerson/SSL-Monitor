# SSL Monitor - Documentation (EN / GR)

## 📘 English Version

### 🔧 Installation
1. Place all files inside a PHP-capable web server (e.g., Apache + PHP).
2. Ensure the script `ssl_monitor` exists and works in CLI (bash).
3. Set correct permissions for:
   - `domains.list` to be writable by the web user (e.g., `www-data` or Hestia user).
   - `cert_status.json` to be readable by PHP.

> ℹ️ The folder `/private/` is an example path for storing your shell scripts and generated files. You can define your own path via the **Settings** menu.

### 📂 File Structure
```
/public_html/
  ├── index.php
  ├── style.css
  ├── script.js
/private/ (or your custom path)
  ├── ssl_monitor.sh
  ├── check_expiry.sh
  ├── domains.list (auto generated)
  ├── cert_status.json (auto generated)
  ├── config.php
```

### 🔐 Login
- Default credentials:
  - Username: `admin`
  - Password: `admin`
- Stored in `config.php` (`LOGIN_USER`, `LOGIN_PASS`)
- Guests no longer see domain data — only the login screen is shown.

### ➕ Add Domain (as logged-in user)
- Fill: `Server`, `Domain`, `Port`
- Use the dropdown to select type: **https**, **smtp**, **imap**, **pop3** — the correct port is auto-filled.
- Click `Add Domain`.
- Entry is saved in `domains.list` with `# AddedByUser`.

### ❌ Delete Domain
- Only user-added domains (`# AddedByUser`) can be removed.
- Click `❌ Delete` on the domain list.

### ⚙️ Settings Panel
Click the **Settings** button (top-right) to easily:
- Change **login username & password**
- Set the **script path** (e.g., `/private/ssl_monitor.sh`)
- Configure your **API key**
- Changes are saved to `config.php`.

### 📋 Run SSL Check
- A cronjob runs `ssl_monitor.sh` daily and saves output to `cert_status.json`.
- You can manually run:
```bash
sudo /path/to/ssl_monitor.sh -f domains.list -j > cert_status.json
```

ℹ️ If you're using a control panel other than HestiaCP:
- Edit `ssl_monitor.sh` and update:
```bash
bin="/usr/local/hestia/bin"
hestia_conf="/usr/local/hestia/conf/hestia.conf"
```
- These paths must reflect your control panel or system setup.

### 📊 View Interface
- Color-coded domains:
  - 🔴 **Red**: Expired or with Errors (shown first)
  - 🟡 **Yellow**: Expires in ≤15 days
  - 🟢 **Green**: Valid SSL
- Errors show the message, e.g. `Error (Could not get certificate information)`
- Filtering: All / Expired / Warning / Domains / IMAP/POP
- Search bar
- Pagination controls:
  - Results per page: 20 (default), 50, 100, All

## 📬 Email Notification Script

### 🔧 Setup
1. Create a script file, e.g. `check_expiry.sh` with executable permissions.
2. Content should run `ssl_monitor.sh` in JSON mode and parse expired or error certs.
3. If any are found, send an email to your chosen address.

ℹ️ In `check_expiry.sh`, set your actual email address:
```bash
EMAIL="info@domain.com"
```

### 🖥️ Example cronjob (every day at 03:00)
```bash
0 3 * * * /path/to/check_expiry.sh
```

### 📨 Example email script (simplified)
```bash
#!/bin/bash
OUTPUT=$(sudo /path/to/ssl_monitor.sh -f /path/to/domains.list -j)
EXPIRED=$(echo "$OUTPUT" | jq -r '.[] | select(.status | test("expired|error"; "i")) | .domain')

if [[ -n "$EXPIRED" ]]; then
    echo -e "The following domains are expired or have issues:\n$EXPIRED" | mail -s "SSL Monitor Alert" info@yourdomain.com
fi
```

### 🖥️ AIO cronjob to get new list and notify by email for every expired ssl (every day at 03:00)
```bash
0 3 * * * sudo /home/YOURUSER/web/YOURDOMAIN/private/ssl_monitor.sh -f /home/YOURUSER/web/YOURDOMAIN/private/domains.list -j 2>/dev/null | grep -F -A10000 '[' | sudo tee /home/YOURUSER/web/YOURDOMAIN/private/cert_status.json > /dev/null && /home/YOURUSER/web/YOURDOMAIN/private/check_expiry.sh
```

---

#### 🌟 Credits

A big thanks to [sahsanu](https://github.com/sahsanu) for the inspiration and the majority of the Bash script — his work formed the foundation of this project.

---

## 📘 Ελληνική Έκδοση

### 🔧 Εγκατάσταση
1. Αντιγράψτε όλα τα αρχεία σε έναν PHP server (π.χ. Apache + PHP).
2. Βεβαιωθείτε ότι το `ssl_monitor` script λειτουργεί στο bash.
3. Ρυθμίστε δικαιώματα:
   - Το `domains.list` πρέπει να είναι εγγράψιμο από τον web χρήστη.
   - Το `cert_status.json` πρέπει να είναι αναγνώσιμο από PHP.

> ℹ️ Ο φάκελος `/private/` είναι ενδεικτικός. Μπορείτε να επιλέξετε οποιοδήποτε path για τα script & δεδομένα — ορίζεται μέσα από το μενού **Settings**.

### 📂 Δομή φακέλων
```
/public_html/
  ├── index.php
  ├── style.css
  ├── script.js
/private/ (ή οποιοδήποτε path επιλέξετε)
  ├── ssl_monitor.sh
  ├── check_expiry.sh
  ├── domains.list (αυτόματη δημιουργία)
  ├── cert_status.json (αυτόματη δημιουργία)
  ├── config.php
```

### 🔐 Σύνδεση
- Default στοιχεία:
  - Χρήστης: `admin`
  - Κωδικός: `admin`
- Αλλάζουν μέσα στο `config.php` (`LOGIN_USER`, `LOGIN_PASS`)
- Οι επισκέπτες δεν βλέπουν τη λίστα domain — εμφανίζεται μόνο η φόρμα login.

### ➕ Προσθήκη Domain
- Συμπληρώστε: `Server`, `Domain`, `Port`
- Επιλέξτε από dropdown: **https**, **smtp**, **imap**, **pop3** — το port ενημερώνεται αυτόματα.
- Πατήστε `Add Domain` για αποθήκευση (σημειώνεται με `# AddedByUser`)

### ❌ Διαγραφή Domain
- Γίνεται μόνο για όσα πρόσθεσε ο χρήστης.
- Πατήστε `❌ Delete` στη λίστα.

### ⚙️ Μενού Ρυθμίσεων (Settings)
Από το κουμπί **Settings** (επάνω δεξιά) μπορείτε να:
- Αλλάξετε **όνομα χρήστη και κωδικό**
- Ορίσετε νέο **μονοπάτι script**
- Περάσετε **API key**

Όλα αποθηκεύονται στο `config.php`.

### 📋 Έλεγχος SSL χειροκίνητα
- Ένα cronjob εκτελεί κάθε μέρα το `ssl_monitor.sh` και αποθηκεύει το json.
- Μπορείτε και χειροκίνητα:
```bash
sudo /path/to/ssl_monitor.sh -f domains.list -j > cert_status.json
```

ℹ️ Αν χρησιμοποιείτε άλλο control panel εκτός του HestiaCP:
- Ανοίξτε το `ssl_monitor.sh` και τροποποιήστε:
```bash
bin="/usr/local/hestia/bin"
hestia_conf="/usr/local/hestia/conf/hestia.conf"
```
- Οι διαδρομές πρέπει να προσαρμοστούν στο δικό σας σύστημα.

### 📊 Περιβάλλον Web
- Προβολή grouped (ανά server)
- Φίλτρα: Όλα / Expired / Warning / Domains / IMAP/POP
- Αναζήτηση και σελιδοποίηση
- Εναλλαγή: `Πλήρης Προβολή`, `Ομαδοποίηση Server`

## 📬 Script Ειδοποίησης μέσω Email

### 🔧 Ρύθμιση (GR)
1. Δημιουργήστε ένα bash script, π.χ. `check_expiry.sh` με δικαιώματα εκτέλεσης.
2. Το script εκτελεί το `ssl_monitor.sh` σε JSON mode και ελέγχει για expired/error.
3. Αν βρει κάποιο, στέλνει email σε προκαθορισμένο email.

### 🖥️ Παράδειγμα cronjob (κάθε μέρα στις 03:00)
```bash
0 3 * * * /path/to/check_expiry.sh
```

### 📨 Παράδειγμα script email (απλό)
```bash
#!/bin/bash
OUTPUT=$(sudo /path/to/ssl_monitor.sh -f /path/to/domains.list -j)
EXPIRED=$(echo "$OUTPUT" | jq -r '.[] | select(.status | test("expired|error"; "i")) | .domain')

if [[ -n "$EXPIRED" ]]; then
    echo -e "Τα παρακάτω domains έχουν πρόβλημα ή έχουν λήξει:\n$EXPIRED" | mail -s "SSL Monitor Alert" info@yourdomain.com
fi
```
---

### 🖥️ AIO cronjob για αυτόματη ενημέρωση της λίστας καθώς και ειδπποίησης μέσω email για ληγμένα πιστοποιητικά SSL (every day at 03:00)
```bash
0 3 * * * sudo /home/YOURUSER/web/YOURDOMAIN/private/ssl_monitor.sh -f /home/YOURUSER/web/YOURDOMAIN/private/domains.list -j 2>/dev/null | grep -F -A10000 '[' | sudo tee /home/YOURUSER/web/YOURDOMAIN/private/cert_status.json > /dev/null && /home/YOURUSER/web/YOURDOMAIN/private/check_expiry.sh
```
---

#### 🌟 Credits

Μεγάλο ευχαριστώ στον [sahsanu](https://github.com/sahsanu) για την έμπνευση και το μεγαλύτερο μέρος του Bash script — η δουλειά του αποτέλεσε τη βάση αυτού του έργου.

---

#### P.S. It works with HestiaCP but it can work everywhere with the correct changes.

---

---

📌 **Τελευταία ενημέρωση: 04/05/2025

---
