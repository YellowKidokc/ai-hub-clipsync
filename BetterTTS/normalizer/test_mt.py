from theophysics_normalizer import TheophysicsNormalizer
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

n = TheophysicsNormalizer()

with open(r"O:\_Theophysics_v4\99_MATH_APPENDIX\__ MASTER EQ\THE THEOPHYSICS MASTER EQUATION.md", "r", encoding="utf-8") as f:
    raw = f.read()

result = n.normalize(raw)

# Write full output
with open("test_mt_output.txt", "w", encoding="utf-8") as f:
    f.write(result)

# Write equation lookup test
with open("test_mt_lookups.txt", "w", encoding="utf-8") as f:
    f.write(f"Total output lines: {len(result.split(chr(10)))}\n\n")
    
    test_eqs = [
        r"\Box\chi + m^2\chi + \frac{\lambda}{6}\chi^3 + \xi R\chi = J_{grace} + g_\Phi \cdot \Phi^2",
        r"\chi[\Omega] = \int\prod_{i=1}^{10} X_i \, d\mu",
        r"G_{eff} = \frac{G}{1 + 8\pi G\xi\chi^2}",
        r"H = -\sum p_i \log p_i",
        r"F = Gm_1m_2/r^2",
        r"E = mc^2",
        r"dS/dt \geq 0",
        r"dC/dt = G(C) - S(C) + \Phi(C) \cdot \varepsilon",
        r"\nabla \cdot \mathbf{E} = \frac{\rho}{\epsilon_0}",
    ]
    f.write("=== MASTER FILE LOOKUP TEST ===\n")
    for eq in test_eqs:
        t = n.find_equation_translation(eq)
        f.write(f"  [{eq[:70]}] => {t}\n")
    
    # Count how many $...$ blocks exist in raw
    import re
    display_math = re.findall(r'\$\$(.*?)\$\$', raw, re.DOTALL)
    inline_math = re.findall(r'(?<!\$)\$(?!\$)(.*?)(?<!\$)\$', raw)
    f.write(f"\n=== MATH BLOCK COUNTS ===\n")
    f.write(f"Display math ($$...$$): {len(display_math)}\n")
    f.write(f"Inline math ($...$): {len(inline_math)}\n")
    
    # Show first 5 display math blocks and what they resolved to
    f.write(f"\n=== FIRST 10 DISPLAY MATH BLOCKS ===\n")
    for i, eq in enumerate(display_math[:10]):
        clean = eq.strip()
        translation = n.find_equation_translation(clean)
        f.write(f"  [{i}] RAW: {clean[:80]}...\n")
        f.write(f"       HIT: {translation}\n\n")

print("Done. Check test_mt_output.txt and test_mt_lookups.txt")
