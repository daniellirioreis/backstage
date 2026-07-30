#!/usr/bin/env python3
"""
Backstage — Stress Test
Uso: python3 stress_test.py
Requer: pip install requests
"""

import requests
import threading
import time
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

BASE_URL = "https://backstage-staging-6j0k.onrender.com"
CPF      = "078.166.916-29"
PASSWORD = "120188"

ROUTES = [
    ("Dashboard",      "GET", "/"),
    ("Eventos",        "GET", "/events"),
    ("Equipes",        "GET", "/teams"),
    ("Turnos",         "GET", "/shifts"),
    ("Usuários",       "GET", "/users"),
    ("Presenças",      "GET", "/attendances"),
    ("Rel. Fechamento","GET", "/reports/closing"),
]

CONCURRENCY = 10   # usuários simultâneos por rota
REPETITIONS = 3    # quantas vezes cada rota é chamada por usuário


def login():
    import re
    session = requests.Session()
    try:
        # 1. Pega CSRF do login
        r = session.get(f"{BASE_URL}/login", timeout=20)
        match = re.search(r'name="authenticity_token"\s+value="([^"]+)"', r.text)
        if not match:
            return None
        csrf = match.group(1)

        # 2. Faz login
        r2 = session.post(f"{BASE_URL}/login", data={
            "user[login]": CPF,
            "user[password]": PASSWORD,
            "authenticity_token": csrf,
        }, allow_redirects=True, timeout=20)
        if "/login" in r2.url:
            return None

        # 3. Seleciona o primeiro evento disponível
        r3 = session.get(f"{BASE_URL}/events/select", timeout=20, allow_redirects=True)
        event_match = re.search(r'name="event_id"\s+value="(\d+)"', r3.text)
        if event_match:
            event_id = event_match.group(1)
            csrf_match = re.search(r'name="authenticity_token"\s+value="([^"]+)"', r3.text)
            csrf2 = csrf_match.group(1) if csrf_match else csrf
            session.post(f"{BASE_URL}/events/select", data={
                "event_id": event_id,
                "authenticity_token": csrf2,
            }, allow_redirects=True, timeout=20)

        return session
    except Exception as e:
        print(f"  Erro no login: {e}")
        return None


def hit(session, method, path):
    url = BASE_URL + path
    start = time.time()
    try:
        r = getattr(session, method.lower())(url, timeout=30, allow_redirects=True)
        elapsed = (time.time() - start) * 1000
        return {"status": r.status_code, "ms": elapsed, "ok": r.status_code < 400}
    except Exception as e:
        return {"status": 0, "ms": (time.time() - start) * 1000, "ok": False, "err": str(e)}


def worker_with_session(session, route_name, method, path):
    results = []
    for _ in range(REPETITIONS):
        r = hit(session, method, path)
        r["route"] = route_name
        results.append(r)
    return results


def run_test():
    print(f"\n{'='*60}")
    print(f"  BACKSTAGE STRESS TEST — {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}")
    print(f"  URL: {BASE_URL}")
    print(f"  Usuários simultâneos: {CONCURRENCY}  |  Repetições: {REPETITIONS}")
    print(f"{'='*60}\n")

    # Verifica se o site está no ar
    print("🔍 Verificando conexão...")
    try:
        r = requests.get(f"{BASE_URL}/login", timeout=20)
        print(f"  ✅ Site respondendo ({r.status_code})\n")
    except Exception as e:
        print(f"  ❌ Site inacessível: {e}\n")
        return

    # Pré-cria sessões autenticadas (uma por usuário simulado)
    print(f"🔐 Criando {CONCURRENCY} sessões autenticadas (sequencial)...")
    sessions = []
    for i in range(CONCURRENCY):
        s = login()
        if s:
            sessions.append(s)
            print(f"   sessão {i+1}/{CONCURRENCY} OK", end="\r")
        else:
            print(f"   ⚠️  sessão {i+1} falhou, pulando")
    print(f"\n  ✅ {len(sessions)} sessões prontas\n")

    if not sessions:
        print("  ❌ Nenhuma sessão disponível, abortando.\n")
        return

    all_results = {name: [] for name, _, _ in ROUTES}

    for name, method, path in ROUTES:
        print(f"🚀 Testando: {name} ({len(sessions)} usuários × {REPETITIONS} req)")
        futures = []
        with ThreadPoolExecutor(max_workers=len(sessions)) as executor:
            for s in sessions:
                futures.append(executor.submit(worker_with_session, s, name, method, path))
        for f in as_completed(futures):
            all_results[name].extend(f.result())
        times = [r["ms"] for r in all_results[name] if r["ok"]]
        errors = sum(1 for r in all_results[name] if not r["ok"])
        total  = len(all_results[name])
        if times:
            print(f"   média: {statistics.mean(times):.0f}ms  |  p95: {sorted(times)[int(len(times)*0.95)-1]:.0f}ms  |  erros: {errors}/{total}")
        else:
            print(f"   ❌ Todos falharam ({errors}/{total})")
        print()

    # Resumo final
    print(f"\n{'='*60}")
    print("  RESUMO FINAL")
    print(f"{'='*60}")
    print(f"  {'Rota':<22} {'Req':>5} {'Erros':>6} {'Média':>8} {'Mín':>7} {'Máx':>7} {'P95':>8}")
    print(f"  {'-'*22} {'-'*5} {'-'*6} {'-'*8} {'-'*7} {'-'*7} {'-'*8}")
    for name, _, _ in ROUTES:
        rs = all_results[name]
        times = sorted([r["ms"] for r in rs if r["ok"]])
        errors = sum(1 for r in rs if not r["ok"])
        total = len(rs)
        if times:
            avg  = statistics.mean(times)
            mn   = min(times)
            mx   = max(times)
            p95  = times[int(len(times)*0.95)-1]
            flag = "🟢" if avg < 500 else ("🟡" if avg < 1500 else "🔴")
            print(f"  {flag} {name:<20} {total:>5} {errors:>6} {avg:>7.0f}ms {mn:>6.0f}ms {mx:>6.0f}ms {p95:>7.0f}ms")
        else:
            print(f"  🔴 {name:<20} {total:>5} {errors:>6} {'—':>8} {'—':>7} {'—':>7} {'—':>8}")
    print(f"\n  🟢 < 500ms   🟡 500–1500ms   🔴 > 1500ms")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    run_test()
