import pandas as pd

df = pd.read_excel("MATH_TRANSLATION_MASTER.xlsx")
print(f"Columns: {list(df.columns)}")
print(f"Rows: {len(df)}")

print("\n=== FIRST 20 ENTRIES ===")
for i, row in df.head(20).iterrows():
    latex = str(row.get("latex", ""))[:70]
    audio = str(row.get("tts_audio", ""))[:70]
    print(f"  [{latex}] => [{audio}]")

print("\n=== SEARCH: chi, grace, coherence ===")
for i, row in df.iterrows():
    latex = str(row.get("latex", "")).lower()
    if any(kw in latex for kw in ["chi", "grace", "coherence", "box", "j_"]):
        print(f"  [{str(row['latex'])[:70]}] => [{str(row['tts_audio'])[:70]}]")
