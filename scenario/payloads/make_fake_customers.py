#!/usr/bin/env python3
"""
ShadowTrace - Génère un fichier clients 100 % FACTICE (aucune donnée réelle).
  python make_fake_customers.py --out C:\\Finance\\Export\\clients_2026.csv --rows 12418
"""
import argparse
import csv
import random
import unicodedata
from pathlib import Path

FIRST = ["Camille", "Léa", "Hugo", "Lucas", "Inès", "Nora", "Yanis", "Sarah", "Adam", "Chloé", "Mehdi", "Emma"]
LAST = ["Martin", "Bernard", "Dubois", "Lefèvre", "Moreau", "Diallo", "Nguyen", "Garcia", "Haddad", "Petit"]
CITIES = ["Paris", "Lyon", "Bruxelles", "Lille", "Nantes", "Liège", "Marseille", "Toulouse"]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--rows", type=int, default=12418)
    ap.add_argument("--seed", type=int, default=2026)
    a = ap.parse_args()
    rnd = random.Random(a.seed)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    with a.out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id_client", "nom", "prenom", "email", "telephone", "ville", "iban_FICTIF", "encours_eur"])
        for i in range(1, a.rows + 1):
            fn, ln = rnd.choice(FIRST), rnd.choice(LAST)
            ascii_ = lambda x: unicodedata.normalize("NFKD", x).encode("ascii", "ignore").decode().lower()
            w.writerow([f"C{i:06d}", ln, fn, f"{ascii_(fn)}.{ascii_(ln)}{i}@example.com",
                        f"+33 6 {rnd.randint(10,99)} {rnd.randint(10,99)} {rnd.randint(10,99)} {rnd.randint(10,99)}",
                        rnd.choice(CITIES), "FR76 0000 " + " ".join(f"{rnd.randint(0,9999):04d}" for _ in range(4)) + " 000",
                        f"{rnd.uniform(0, 25000):.2f}"])
    print(f"{a.rows} clients factices écrits dans {a.out}")


if __name__ == "__main__":
    main()
