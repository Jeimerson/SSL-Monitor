# SSL Monitor - Documentation (EN / GR)

## 📘 English Version

### 🔧 Installation
1. Place all files inside a PHP-capable web server (e.g., Apache + PHP).
2. Ensure the script `ssl_monitor` exists and works in CLI (bash).
3. Set correct permissions for:
   - `domains.list` to be writable by the web user (e.g., `www-data` or Hestia user).
   - `cert_status.json` to be readable by PHP.

### 📂 File Structure
```
/public_html/
  ├── index.php
  ├── style.css
  ├── script.js
/private/
  ├── ssl_monitor.sh
  ├── check_expiry.sh
  ├── domains.list (auto generated)
  ├── cert_status.json (auto generated)
```

### 🔐 Login
- Default credentials:
  - Username: `admin`
  - Password: `admin`
- These are stored in `index.php` (edit `LOGIN_USER` and `LOGIN_PASS`).

### ➕ Add Domain (as logged-in user)
- Fill: `Server`, `Domain`, `Port` (default: 443).
- Click `Add Domain`.
- The domain is saved in `domains.list` with `# AddedByUser` flag.

### ❌ Delete Domain
- Only user-added domains (`# AddedByUser`) can be removed.
- Click `❌ Delete` on the domain list.

### 📋 Run SSL Check
- A cronjob runs `ssl_monitor.sh` daily and saves output to `cert_status.json`.
- You can manually run:
```bash
sudo /path/to/ssl_monitor.sh -f domains.list -j > cert_status.json
```

### 📊 View Interface
- See grouped domains (by server)
- Filter by: All / Expired / Warning / Domains / IMAP/POP
- Search bar and pagination available
- Toggle: `Show All Details`, `Group By Server`

## 📬 Email Notification Script

### 🔧 Setup
1. Create a script file, e.g. `check_expiry.sh` with executable permissions.
2. Content should run `ssl_monitor.sh` in JSON mode and parse expired or error certs.
3. If any are found, send an email to your chosen address.

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
### 🖥️ AIO cronjob to get new list and notify by email for every expired ssl(every day at 03:00)
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

### 📂 Δομή φακέλων
```
/public_html/
  ├── index.php
  ├── style.css
  ├── script.js
/private/
  ├── ssl_monitor.sh
  ├── check_expiry.sh
  ├── domains.list (αυτόματη δημιουργία)
  ├── cert_status.json (αυτόματη δημιουργία)
```

### 🔐 Σύνδεση
- Default στοιχεία:
  - Χρήστης: `admin`
  - Κωδικός: `admin`
- Τα αλλάζετε στο `index.php` (μεταβλητές `LOGIN_USER`, `LOGIN_PASS`).

### ➕ Προσθήκη Domain (μόνο συνδεδεμένοι)
- Συμπληρώστε: `Server`, `Domain`, `Port` (προεπιλογή: 443).
- Πατήστε `Add Domain`.
- Το domain καταχωρείται στο `domains.list` με `# AddedByUser`.

### ❌ Διαγραφή Domain
- Γίνεται μόνο για domains που προστέθηκαν από χρήστες.
- Πατήστε `❌ Delete` στη λίστα.

### 📋 Έλεγχος SSL χειροκίνητα
- Ένα cronjob εκτελεί κάθε μέρα το `ssl_monitor.sh` και αποθηκεύει το json.
- Μπορείτε και χειροκίνητα:
```bash
sudo /path/to/ssl_monitor.sh -f domains.list -j > cert_status.json
```

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

📌 **Τελευταία ενημέρωση: 30/04/2025

---
