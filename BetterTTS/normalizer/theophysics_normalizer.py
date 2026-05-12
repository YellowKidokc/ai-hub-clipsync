"""
Theophysics Text Normalization Layer
=====================================
Converts Theophysics-specific symbols, equations, and notation to spoken form.
Designed to work with the TTS pipeline for the 188 Axiom Framework.

Author: David Lowe / Theophysics Project
"""

import os
import re
from typing import Dict, List, Optional, Tuple

import pandas as pd

# Optional AI fallback for equations not in master file
try:
    from ai_math_translator import AIMathTranslator
    AI_AVAILABLE = True
except ImportError:
    AI_AVAILABLE = False


###############################################################################
# Comprehensive LaTeX-to-Speech Engine
# =====================================
# Translates arbitrary LaTeX math into natural spoken English for TTS.
# Handles: Greek letters, operators, relations, fractions, integrals,
#          summations, subscripts, superscripts, decorators, bra-ket,
#          set theory, logic, calculus, and all standard mathematical notation.
###############################################################################

# --- LaTeX command → spoken word maps ---

_LATEX_GREEK = {
    # lowercase
    "alpha": "alpha", "beta": "beta", "gamma": "gamma", "delta": "delta",
    "epsilon": "epsilon", "varepsilon": "epsilon", "zeta": "zeta",
    "eta": "eta", "theta": "theta", "vartheta": "theta",
    "iota": "iota", "kappa": "kappa", "varkappa": "kappa",
    "lambda": "lambda", "mu": "mu", "nu": "nu",
    "xi": "xi", "pi": "pi", "varpi": "pi",
    "rho": "rho", "varrho": "rho", "sigma": "sigma", "varsigma": "sigma",
    "tau": "tau", "upsilon": "upsilon",
    "phi": "phi", "varphi": "phi", "chi": "chi",
    "psi": "psi", "omega": "omega",
    # uppercase
    "Alpha": "Alpha", "Beta": "Beta", "Gamma": "Gamma", "Delta": "Delta",
    "Epsilon": "Epsilon", "Zeta": "Zeta", "Eta": "Eta", "Theta": "Theta",
    "Iota": "Iota", "Kappa": "Kappa", "Lambda": "Lambda", "Mu": "Mu",
    "Nu": "Nu", "Xi": "Xi", "Pi": "Pi", "Rho": "Rho", "Sigma": "Sigma",
    "Tau": "Tau", "Upsilon": "Upsilon", "Phi": "Phi", "Chi": "Chi",
    "Psi": "Psi", "Omega": "Omega",
}

_LATEX_OPERATORS = {
    # Arithmetic
    "cdot": "times", "times": "times", "div": "divided by",
    "pm": "plus or minus", "mp": "minus or plus",
    # Relations
    "eq": "equals", "neq": "is not equal to", "ne": "is not equal to",
    "leq": "is less than or equal to", "le": "is less than or equal to",
    "geq": "is greater than or equal to", "ge": "is greater than or equal to",
    "ll": "is much less than", "gg": "is much greater than",
    "approx": "is approximately", "sim": "is proportional to",
    "simeq": "is approximately equal to", "cong": "is congruent to",
    "equiv": "is identically equal to", "propto": "is proportional to",
    "prec": "precedes", "succ": "succeeds",
    # Arrows
    "to": "goes to", "rightarrow": "goes to", "Rightarrow": "implies",
    "leftarrow": "comes from", "Leftarrow": "is implied by",
    "leftrightarrow": "is equivalent to", "Leftrightarrow": "if and only if",
    "implies": "implies", "iff": "if and only if",
    "mapsto": "maps to", "longmapsto": "maps to",
    "uparrow": "increases", "downarrow": "decreases",
    # Set theory
    "in": "is in", "notin": "is not in", "ni": "contains",
    "subset": "is a subset of", "subseteq": "is a subset of or equal to",
    "supset": "is a superset of", "supseteq": "is a superset of or equal to",
    "cup": "union", "cap": "intersection",
    "setminus": "minus", "emptyset": "the empty set", "varnothing": "the empty set",
    # Logic
    "forall": "for all", "exists": "there exists", "nexists": "there does not exist",
    "neg": "not", "lnot": "not",
    "land": "and", "lor": "or", "wedge": "and", "vee": "or",
    "vdash": "proves", "models": "models", "therefore": "therefore",
    "because": "because",
    # Calculus / analysis
    "partial": "partial", "nabla": "the gradient of", "grad": "the gradient of",
    "infty": "infinity",
    # Spacing / structure (silent)
    "quad": " ", "qquad": " ", ",": " ", ";": " ", "!": "",
    "left": "", "right": "", "big": "", "Big": "", "bigg": "", "Bigg": "",
    "bigl": "", "bigr": "", "Bigl": "", "Bigr": "",
    # Misc
    "hbar": "h bar", "ell": "l", "Re": "the real part of",
    "Im": "the imaginary part of", "wp": "Weierstrass p",
    "aleph": "aleph", "beth": "beth",
    "dagger": "dagger", "ddagger": "double dagger",
    "star": "star", "circ": "composed with",
    "bullet": "dot", "diamond": "diamond",
    "oplus": "direct sum", "otimes": "tensor product",
    "perp": "perpendicular to", "parallel": "parallel to",
    "angle": "angle", "measuredangle": "angle",
    # Dots
    "dots": "dot dot dot", "ldots": "dot dot dot", "cdots": "dot dot dot",
    "vdots": "vertical dots", "ddots": "diagonal dots",
    # Text formatting (pass through)
    "mathrm": "", "mathbf": "", "mathit": "", "mathsf": "",
    "mathcal": "", "mathbb": "", "mathfrak": "", "boldsymbol": "",
    "textrm": "", "textbf": "", "textit": "",
    # Brackets (handled structurally but fallback here)
    "langle": "open angle bracket", "rangle": "close angle bracket",
    "lfloor": "floor of", "rfloor": "end floor",
    "lceil": "ceiling of", "rceil": "end ceiling",
    "lvert": "absolute value of", "rvert": "end absolute value",
    "lVert": "the norm of", "rVert": "end norm",
    # Additional common commands
    "log": "log", "ln": "natural log", "exp": "e to the",
    "sin": "sine", "cos": "cosine", "tan": "tangent",
    "sec": "secant", "csc": "cosecant", "cot": "cotangent",
    "arcsin": "arc sine", "arccos": "arc cosine", "arctan": "arc tangent",
    "sinh": "hyperbolic sine", "cosh": "hyperbolic cosine",
    "tanh": "hyperbolic tangent",
    "det": "the determinant of", "dim": "the dimension of",
    "ker": "the kernel of", "lim": "the limit", "limsup": "the limit supremum",
    "liminf": "the limit infimum",
    "max": "the maximum", "min": "the minimum",
    "sup": "the supremum", "inf": "the infimum",
    "arg": "the argument of",
    "deg": "degrees", "hom": "hom",
    "Tr": "the trace of", "tr": "the trace of",
    "diag": "the diagonal of",
    "sgn": "the sign of",
    "mod": "mod", "bmod": "mod", "pmod": "mod",
    "gcd": "the greatest common divisor of",
    "lcm": "the least common multiple of",
    "operatorname": "",
    # Theophysics-specific
    "Box": "the d'Alembertian of", "box": "the d'Alembertian of",
    "square": "the d'Alembertian of",
    "mathcal{L}": "the Lagrangian",
    "mathcal{H}": "the Hamiltonian",
    "mathcal{F}": "the free energy",
}

# Decorators: \hat{x} → "x hat"
_LATEX_DECORATORS = {
    "hat": "hat", "widehat": "hat",
    "bar": "bar", "overline": "bar",
    "tilde": "tilde", "widetilde": "tilde",
    "vec": "vector", "overrightarrow": "vector",
    "dot": "dot", "ddot": "double dot",
    "acute": "acute", "grave": "grave",
    "breve": "breve", "check": "check",
    "underline": "underline",
    "overbrace": "", "underbrace": "",
    "cancel": "", "bcancel": "", "xcancel": "",
}

# Named ordinals for superscripts
_ORDINAL_SUFFIXES = {
    "0": "zeroth", "1": "first", "2": "squared", "3": "cubed",
    "4": "to the fourth", "5": "to the fifth", "6": "to the sixth",
    "7": "to the seventh", "8": "to the eighth", "9": "to the ninth",
    "10": "to the tenth", "n": "to the n", "N": "to the N",
    "k": "to the k", "m": "to the m", "i": "to the i", "j": "to the j",
    "-1": "inverse", "-2": "to the negative two",
}


###############################################################################
# Level 4a: Units & Scientific Notation
###############################################################################

# Physics units — ordered longest-first to prevent partial matches
_UNIT_MAP = [
    # Compound units (must come first)
    ("km/s/Mpc", "kilometers per second per megaparsec"),
    ("km/s", "kilometers per second"),
    ("m/s²", "meters per second squared"),
    ("m/s^2", "meters per second squared"),
    ("m/s", "meters per second"),
    ("J/K", "joules per kelvin"),
    ("J/mol", "joules per mole"),
    ("W/m²", "watts per square meter"),
    ("kg/m³", "kilograms per cubic meter"),
    ("N/m²", "newtons per square meter"),
    ("kg·m/s", "kilogram meters per second"),
    # Energy
    ("GeV", "giga electron volts"),
    ("MeV", "mega electron volts"),
    ("keV", "kilo electron volts"),
    ("eV", "electron volts"),
    ("TeV", "tera electron volts"),
    # Frequency
    ("GHz", "gigahertz"),
    ("MHz", "megahertz"),
    ("kHz", "kilohertz"),
    ("THz", "terahertz"),
    ("Hz", "hertz"),
    # Distance
    ("Mpc", "megaparsecs"),
    ("kpc", "kiloparsecs"),
    ("pc", "parsecs"),
    ("km", "kilometers"),
    ("cm", "centimeters"),
    ("mm", "millimeters"),
    ("nm", "nanometers"),
    ("pm", "picometers"),
    ("fm", "femtometers"),
    # Mass
    ("kg", "kilograms"),
    ("mg", "milligrams"),
    # Temperature
    ("°C", "degrees Celsius"),
    ("°F", "degrees Fahrenheit"),
    # Pressure / Force
    ("Pa", "pascals"),
    ("atm", "atmospheres"),
    # Electrical
    ("kW", "kilowatts"),
    ("MW", "megawatts"),
    # Time
    ("Gyr", "billion years"),
    ("Myr", "million years"),
    ("kyr", "thousand years"),
    # Information
    ("bits", "bits"),
    ("nats", "nats"),
    # Astronomy-specific
    ("M_☉", "solar masses"),
    ("L_☉", "solar luminosities"),
    ("R_☉", "solar radii"),
]

# Scientific notation patterns
_SCI_NOTATION_PATTERNS = [
    # 10^{-33} or 10^{5} etc
    (re.compile(r"10\s*\^\s*\{?\s*(-?\d+)\s*\}?"), lambda m: f"ten to the {_speak_exponent(m.group(1))}"),
    # 4.2σ or 4–5σ or 6σ  (σ must follow a digit directly)
    (re.compile(r"(\d+(?:\.\d+)?)\s*[–-]\s*(\d+(?:\.\d+)?)\s*σ"), lambda m: f"{m.group(1)} to {m.group(2)} sigma"),
    (re.compile(r"(\d+(?:\.\d+)?)\s*σ"), lambda m: f"{m.group(1)} sigma"),
    # z ≈ 1.5–2.5  (redshift ranges)
    (re.compile(r"z\s*[≈≃~]\s*(\d+(?:\.\d+)?)\s*[–-]\s*(\d+(?:\.\d+)?)"), lambda m: f"redshift approximately {m.group(1)} to {m.group(2)}"),
]


def _speak_exponent(exp_str: str) -> str:
    """Convert an exponent string to spoken form."""
    exp_str = exp_str.strip()
    if exp_str.startswith('-'):
        num = exp_str[1:]
        return f"negative {num}"
    return exp_str


###############################################################################
# Level 4b: Derivative / Differential Equation Patterns (raw text, not LaTeX)
###############################################################################

_DERIVATIVE_PATTERNS = [
    # Partial derivatives: ∂x/∂t or \partial x / \partial t
    (re.compile(r"∂\s*(\w+)\s*/\s*∂\s*(\w+)"), r"the partial derivative of \1 with respect to \2"),
    (re.compile(r"∂²\s*(\w+)\s*/\s*∂\s*(\w+)\s*²"), r"the second partial derivative of \1 with respect to \2"),
    # Ordinary derivatives: dC/dt, dx/dt, d²x/dt²
    (re.compile(r"d²\s*(\w+)\s*/\s*dt²"), r"the second derivative of \1 with respect to t"),
    (re.compile(r"d\s*(\w+)\s*/\s*d\s*(\w+)"), r"the derivative of \1 with respect to \2"),
    # D'Alembertian: □χ or □\chi
    (re.compile(r"□\s*(\w+)"), r"the d'Alembertian of \1"),
    # Nabla with subscript: ∇_μ
    (re.compile(r"∇\s*_\s*(\w+)"), r"the covariant derivative sub \1 of"),
    (re.compile(r"∇"), "the gradient of"),
]


###############################################################################
# Level 4c: Section References & Framework Shorthand
###############################################################################

_REFERENCE_PATTERNS = [
    # §5.4 → "section 5 point 4"
    (re.compile(r"§\s*(\d+)\.(\d+)"), r"section \1 point \2"),
    (re.compile(r"§\s*(\d+)"), r"section \1"),
    # Framework codes: TKC-3, SKC-1, DP-00, LLC, ISO-037
    (re.compile(r"\bTKC[- ]?(\d+)"), r"T K C \1"),
    (re.compile(r"\bSKC[- ]?(\d+)"), r"S K C \1"),
    (re.compile(r"\bDP[- ]?(\d+)"), r"D P \1"),
    (re.compile(r"\bISO[- ]?(\d+)"), r"I S O \1"),
    (re.compile(r"\bJSC[- ]?(\d+)"), r"J S C \1"),
    (re.compile(r"\bLLC\b"), "the Lowe Coherence Lagrangian"),
    (re.compile(r"\bCKG\b"), "C K G"),
    (re.compile(r"\bPOF\b"), "P O F"),
    (re.compile(r"\bDESI\b"), "D E S I"),
    (re.compile(r"\bPEAR\b"), "P E A R"),
    (re.compile(r"\bGCP\b"), "G C P"),
    (re.compile(r"\bAPCT\b"), "A P C T"),
    # Paper references: Paper 7, P07
    (re.compile(r"\bP(\d{2})\b"), r"Paper \1"),
    # fσ₈ or fσ_8
    (re.compile(r"f[σ]_?8"), "f sigma eight"),
    (re.compile(r"fσ₈"), "f sigma eight"),
]


###############################################################################
# Level 4d: Hebrew / Greek / Transliterated Theology Terms
###############################################################################

_THEOLOGY_TERMS = {
    # Hebrew
    "שָׁלוֹם": "shalom",
    "שׁלום": "shalom",
    "שלום": "shalom",
    "תּוֹרָה": "torah",
    "תורה": "torah",
    "אמת": "emet",
    "חסד": "chesed",
    "כבוד": "kavod",
    "רוח": "ruach",
    "נפש": "nefesh",
    "אלהים": "elohim",
    "יהוה": "the Lord",
    "אדני": "adonai",
    "צדק": "tsedek",
    "משיח": "mashiach",
    "קדוש": "kadosh",
    "ברית": "brit",
    "עולם": "olam",
    "תשובה": "teshuvah",
    "חיים": "chayyim",
    "דבר": "davar",
    "אמונה": "emunah",
    # Greek (Biblical / theological)
    "ἑνότης": "henotes",
    "ἀνακεφαλαίωσις": "anakephalaiosis",
    "κατάρτισις": "katartisis",
    "λόγος": "logos",
    "Λόγος": "Logos",
    "πνεῦμα": "pneuma",
    "σάρξ": "sarx",
    "ψυχή": "psyche",
    "ἀγάπη": "agape",
    "χάρις": "charis",
    "πίστις": "pistis",
    "ἐλπίς": "elpis",
    "δόξα": "doxa",
    "κένωσις": "kenosis",
    "θεός": "theos",
    "σωτηρία": "soteria",
    "ἐκκλησία": "ekklesia",
    "βασιλεία": "basileia",
    "μετάνοια": "metanoia",
    "παρουσία": "parousia",
    "ἀποκάλυψις": "apokalypsis",
    "εἰρήνη": "eirene",
    "κοινωνία": "koinonia",
    "δικαιοσύνη": "dikaiosyne",
    "ἁμαρτία": "hamartia",
    "ὑπόστασις": "hypostasis",
    "οὐσία": "ousia",
    "πρόσωπον": "prosopon",
    "φύσις": "physis",
    "ἐνέργεια": "energeia",
    "θέωσις": "theosis",
    "περιχώρησις": "perichoresis",
    # Transliterated forms (Latin alphabet)
    "katharoi": "katharoi",
    "eirhne": "eirene",
    "henotes": "henotes",
    "anakephalaiosis": "anakephalaiosis",
    "kenosis": "kenosis",
    "theosis": "theosis",
    "perichoresis": "perichoresis",
    "homoousios": "homoousios",
    "hypostasis": "hypostasis",
}


###############################################################################
# Level 4e: Theophysics Framework Vocabulary
###############################################################################

_FRAMEWORK_TERMS = {
    # Core fields and concepts
    "χ-field": "chi field",
    "chi-field": "chi field",
    "χ field": "chi field",
    "χ[Ω]": "chi of Omega",
    "Logos field": "Logos field",
    "Logos-field": "Logos field",
    "grace source term": "the Grace Source Term",
    "Grace Source Term": "the Grace Source Term",
    "will current": "the Will Current",
    "Will Current": "the Will Current",
    "witness field": "the Witness Field",
    "Witness Field": "the Witness Field",
    "coherence functional": "the Coherence Functional",
    "Coherence Functional": "the Coherence Functional",
    "grace constant": "the Grace Constant",
    "Grace Constant": "the Grace Constant",
    "moral energy": "the Moral Energy",
    "Moral Energy": "the Moral Energy",
    "Dorothy Protocol": "the Dorothy Protocol",
    "Terminus Sui": "Terminus Sui",
    "Arrow of Grace": "the Arrow of Grace",
    "David Effect": "the David Effect",
    "Beer-Lambert isomorphism": "the Beer Lambert isomorphism",
    # Equation names
    "Master Equation": "the Master Equation",
    "Minimal Action": "the Minimal Action",
    "Embodiment Equation": "the Embodiment Equation",
    "Modified Uncertainty": "the Modified Uncertainty Principle",
    "Lowe Coherence Lagrangian": "the Lowe Coherence Lagrangian",
    # Variable names that need special reading
    "C_int": "C sub int",
    "G_eff": "G effective",
    "G_{eff}": "G effective",
    "S_local": "S local",
    "S_{local}": "S local",
    "S_max": "S max",
    "S_{max}": "S max",
    "C_grace": "C grace",
    "C_{grace}": "C grace",
    "J_grace": "J grace",
    "J_{grace}": "J grace",
    "W_μ": "W sub mu",
    "W_\\mu": "W sub mu",
    "T_c": "T sub c",
    "K_c": "K sub c",
    "N_0": "N naught",
    "H_0": "H naught",
    "H₀": "H naught",
    "G_0": "G naught",
    "m_χ": "m sub chi",
    "ξ": "xi",
    "κ₀": "kappa naught",
}


def apply_pre_latex_transforms(text: str) -> str:
    """
    Apply all non-LaTeX text transforms before LaTeX processing.
    Handles: units, derivatives, references, theology terms, framework vocab.
    """
    # Framework vocabulary (longest first to avoid partial matches)
    for term, spoken in sorted(_FRAMEWORK_TERMS.items(), key=lambda x: -len(x[0])):
        text = text.replace(term, spoken)

    # Theology terms (Hebrew/Greek scripts and transliterations)
    for term, spoken in sorted(_THEOLOGY_TERMS.items(), key=lambda x: -len(x[0])):
        text = text.replace(term, spoken)

    # Scientific notation patterns
    for pattern, replacement in _SCI_NOTATION_PATTERNS:
        if callable(replacement):
            text = pattern.sub(replacement, text)
        else:
            text = pattern.sub(replacement, text)

    # Units (word boundary aware)
    for unit, spoken in _UNIT_MAP:
        # Match unit after a digit or space
        escaped = re.escape(unit)
        text = re.sub(rf"(\d)\s*{escaped}\b", rf"\1 {spoken}", text)

    # Derivative patterns (raw text, not inside LaTeX)
    for pattern, replacement in _DERIVATIVE_PATTERNS:
        text = pattern.sub(replacement, text)

    # Reference patterns
    for pattern, replacement in _REFERENCE_PATTERNS:
        text = pattern.sub(replacement, text)

    return text


def _find_brace_group(tex: str, start: int) -> tuple:
    """Find matching {} group starting at `start`. Returns (content, end_index)."""
    if start >= len(tex) or tex[start] != '{':
        # No brace group — grab next token (could be \command or single char)
        if start < len(tex):
            if tex[start] == '\\':
                # It's a command like \mu — grab the whole command
                j = start + 1
                if j < len(tex) and tex[j].isalpha():
                    while j < len(tex) and tex[j].isalpha():
                        j += 1
                    return tex[start:j], j
                elif j < len(tex):
                    return tex[start:j + 1], j + 1
            return tex[start], start + 1
        return "", start
    depth = 0
    i = start
    while i < len(tex):
        if tex[i] == '{':
            depth += 1
        elif tex[i] == '}':
            depth -= 1
            if depth == 0:
                return tex[start + 1:i], i + 1
        i += 1
    # Unmatched brace — return rest
    return tex[start + 1:], len(tex)


def _find_optional_group(tex: str, start: int) -> tuple:
    """Find optional [] group. Returns (content_or_None, end_index)."""
    if start >= len(tex) or tex[start] != '[':
        return None, start
    depth = 0
    i = start
    while i < len(tex):
        if tex[i] == '[':
            depth += 1
        elif tex[i] == ']':
            depth -= 1
            if depth == 0:
                return tex[start + 1:i], i + 1
        i += 1
    return None, start


def latex_to_speech(tex: str) -> str:
    """
    Convert a LaTeX math string to natural spoken English for TTS.

    This is the main entry point. It strips delimiters, processes LaTeX
    commands recursively, and returns clean speakable text.
    """
    if not tex or not tex.strip():
        return ""

    # Strip dollar-sign delimiters and display math markers
    tex = tex.strip()
    for delim in ["$$", "$", "\\[", "\\]", "\\(", "\\)"]:
        tex = tex.replace(delim, "")
    # Strip \begin{equation}...\end{equation} etc.
    tex = re.sub(r"\\begin\{(?:equation|align|gather|multline|displaymath)\*?\}", "", tex)
    tex = re.sub(r"\\end\{(?:equation|align|gather|multline|displaymath)\*?\}", "", tex)
    tex = re.sub(r"\\(?:label|tag|nonumber|notag)\{[^}]*\}", "", tex)
    # Strip \boxed{}
    tex = re.sub(r"\\boxed\{", "{", tex)

    result = _translate_latex(tex)

    # Final cleanup
    result = re.sub(r"\s+", " ", result).strip()
    result = re.sub(r"\s+([.,;:!?])", r"\1", result)
    # Remove orphan commas / double punctuation
    result = re.sub(r"[,;]\s*[,;]", ",", result)
    result = re.sub(r"\.\s*\.", ".", result)
    # Clean up double absolute-value phrases → single magnitude phrase
    result = re.sub(
        r"absolute value of (.+?) absolute value of",
        r"the magnitude of \1,",
        result
    )
    # Clean up ket immediately followed by bra → "ket ... bra ..."
    result = re.sub(r"ket (.+?) ket bra", r"ket \1, bra", result)
    return result


def _translate_latex(tex: str) -> str:
    """Recursively translate LaTeX tokens into spoken words."""
    out = []
    i = 0
    n = len(tex)

    while i < n:
        c = tex[i]

        # --- Skip whitespace ---
        if c in (' ', '\t', '\n'):
            out.append(' ')
            i += 1
            continue

        # --- Backslash commands ---
        if c == '\\':
            i += 1
            if i >= n:
                break

            # Special single-char commands: \\ \, \; \! \: \>
            if tex[i] in ('\\', ',', ';', '!', ':', '>', ' '):
                out.append(' ')
                i += 1
                continue

            # Read command name
            cmd_start = i
            if tex[i].isalpha():
                while i < n and tex[i].isalpha():
                    i += 1
                cmd = tex[cmd_start:i]
                # consume optional trailing space
                if i < n and tex[i] == ' ':
                    i += 1
            else:
                # single non-alpha char like \{ \} \| etc.
                cmd = tex[i]
                i += 1
                if cmd in ('{', '}'):
                    out.append(cmd)
                    continue
                if cmd == '|':
                    out.append(' absolute value bar ')
                    continue
                continue

            # ---- Handle specific command families ----

            # \text{...} and friends — just read the content as text
            if cmd in ("text", "textrm", "textbf", "textit", "texttt",
                        "mathrm", "mathbf", "mathit", "mathsf", "mathtt",
                        "mathcal", "mathbb", "mathfrak", "boldsymbol",
                        "operatorname"):
                if i < n and tex[i] == '{':
                    content, i = _find_brace_group(tex, i)
                    out.append(f' {content} ')
                continue

            # \frac{a}{b} → "a over b"
            if cmd == "frac" or cmd == "dfrac" or cmd == "tfrac" or cmd == "cfrac":
                num, i = _find_brace_group(tex, i)
                den, i = _find_brace_group(tex, i)
                num_spoken = _translate_latex(num).strip()
                den_spoken = _translate_latex(den).strip()
                # Simple fractions get a nicer reading
                if len(num_spoken.split()) <= 2 and len(den_spoken.split()) <= 2:
                    out.append(f' {num_spoken} over {den_spoken} ')
                else:
                    out.append(f' the quantity {num_spoken}, divided by the quantity {den_spoken}, ')
                continue

            # \sqrt[n]{x} → "the nth root of x" or "the square root of x"
            if cmd == "sqrt":
                opt, i = _find_optional_group(tex, i)
                body, i = _find_brace_group(tex, i)
                body_spoken = _translate_latex(body).strip()
                if opt:
                    opt_spoken = _translate_latex(opt).strip()
                    out.append(f' the {opt_spoken} root of {body_spoken} ')
                else:
                    out.append(f' the square root of {body_spoken} ')
                continue

            # \int, \iint, \iiint, \oint — integrals
            if cmd in ("int", "iint", "iiint", "oint"):
                prefix = {
                    "int": "the integral",
                    "iint": "the double integral",
                    "iiint": "the triple integral",
                    "oint": "the contour integral",
                }[cmd]
                # Check for limits: _{}^{}
                lower = upper = None
                while i < n and tex[i] in ('_', '^', ' ', '{'):
                    if tex[i] == ' ':
                        i += 1
                        continue
                    if tex[i] == '_':
                        i += 1
                        lower, i = _find_brace_group(tex, i)
                    elif tex[i] == '^':
                        i += 1
                        upper, i = _find_brace_group(tex, i)
                    else:
                        break
                parts = [prefix]
                if lower is not None:
                    parts.append(f'from {_translate_latex(lower).strip()}')
                if upper is not None:
                    parts.append(f'to {_translate_latex(upper).strip()}')
                parts.append('of')
                out.append(' '.join(parts) + ' ')
                continue

            # \sum, \prod — big operators
            if cmd in ("sum", "prod", "bigcup", "bigcap", "bigoplus", "bigotimes"):
                prefix = {
                    "sum": "the sum",
                    "prod": "the product",
                    "bigcup": "the union",
                    "bigcap": "the intersection",
                    "bigoplus": "the direct sum",
                    "bigotimes": "the tensor product",
                }[cmd]
                lower = upper = None
                while i < n and tex[i] in ('_', '^', ' ', '{'):
                    if tex[i] == ' ':
                        i += 1
                        continue
                    if tex[i] == '_':
                        i += 1
                        lower, i = _find_brace_group(tex, i)
                    elif tex[i] == '^':
                        i += 1
                        upper, i = _find_brace_group(tex, i)
                    else:
                        break
                parts = [prefix]
                if lower is not None:
                    lower_s = _translate_latex(lower).strip()
                    if '=' in lower:
                        parts.append(f'where {lower_s}')
                    else:
                        parts.append(f'from {lower_s}')
                if upper is not None:
                    parts.append(f'to {_translate_latex(upper).strip()}')
                parts.append('of')
                out.append(' '.join(parts) + ' ')
                continue

            # \lim and limit notation
            if cmd == "lim":
                lower = None
                if i < n and tex[i] == '_':
                    i += 1
                    lower, i = _find_brace_group(tex, i)
                if lower:
                    lower_s = _translate_latex(lower).strip()
                    out.append(f' the limit as {lower_s} of ')
                else:
                    out.append(' the limit of ')
                continue

            # Decorators: \hat{x}, \bar{x}, \vec{x}, \dot{x}, \tilde{x}
            if cmd in _LATEX_DECORATORS:
                word = _LATEX_DECORATORS[cmd]
                if i < n and tex[i] == '{':
                    body, i = _find_brace_group(tex, i)
                    body_spoken = _translate_latex(body).strip()
                    if word:
                        out.append(f' {body_spoken} {word} ')
                    else:
                        out.append(f' {body_spoken} ')
                else:
                    if word:
                        out.append(f' {word} ')
                continue

            # Bra-ket notation: \langle ... | → "bra ...", | ... \rangle → "ket ..."
            if cmd == "langle":
                out.append(' bra ')
                continue
            if cmd == "rangle":
                out.append(' ket ')
                continue

            # \nabla with optional subscript → "the covariant derivative sub mu of"
            if cmd == "nabla":
                if i < n and tex[i] == '_':
                    i += 1
                    sub_body, i = _find_brace_group(tex, i)
                    sub_spoken = _translate_latex(sub_body).strip()
                    out.append(f' the covariant derivative sub {sub_spoken} of ')
                else:
                    out.append(' the gradient of ')
                continue

            # Greek letters
            if cmd in _LATEX_GREEK:
                out.append(f' {_LATEX_GREEK[cmd]} ')
                continue

            # Known operators/relations/symbols
            if cmd in _LATEX_OPERATORS:
                spoken = _LATEX_OPERATORS[cmd]
                if spoken:
                    out.append(f' {spoken} ')
                # Some commands take a brace argument (like \log{x})
                if cmd in ("log", "ln", "exp", "sin", "cos", "tan",
                           "sec", "csc", "cot", "arcsin", "arccos", "arctan",
                           "sinh", "cosh", "tanh", "det", "dim", "ker",
                           "max", "min", "sup", "inf", "arg", "sgn",
                           "Tr", "tr", "diag", "gcd", "lcm"):
                    # Check for subscript limit
                    if i < n and tex[i] == '_':
                        i += 1
                        sub_body, i = _find_brace_group(tex, i)
                        out.append(f' sub {_translate_latex(sub_body).strip()} ')
                continue

            # \underbrace{x}_{label} or \overbrace
            if cmd in ("underbrace", "overbrace"):
                body, i = _find_brace_group(tex, i)
                body_s = _translate_latex(body).strip()
                # Check for label
                if i < n and tex[i] == '_':
                    i += 1
                    label, i = _find_brace_group(tex, i)
                    label_s = _translate_latex(label).strip()
                    out.append(f' {body_s}, which represents {label_s}, ')
                elif i < n and tex[i] == '^':
                    i += 1
                    label, i = _find_brace_group(tex, i)
                    label_s = _translate_latex(label).strip()
                    out.append(f' {body_s}, labeled {label_s}, ')
                else:
                    out.append(f' {body_s} ')
                continue

            # \stackrel{over}{base}
            if cmd == "stackrel":
                over, i = _find_brace_group(tex, i)
                base, i = _find_brace_group(tex, i)
                out.append(f' {_translate_latex(base).strip()} {_translate_latex(over).strip()} ')
                continue

            # \binom{n}{k}
            if cmd in ("binom", "dbinom", "tbinom"):
                top, i = _find_brace_group(tex, i)
                bot, i = _find_brace_group(tex, i)
                out.append(f' {_translate_latex(top).strip()} choose {_translate_latex(bot).strip()} ')
                continue

            # \color{...}{...} — skip color, keep content
            if cmd == "color":
                _, i = _find_brace_group(tex, i)  # skip color name
                if i < n and tex[i] == '{':
                    body, i = _find_brace_group(tex, i)
                    out.append(f' {_translate_latex(body).strip()} ')
                continue

            # \phantom, \hspace, \vspace — skip entirely
            if cmd in ("phantom", "hphantom", "vphantom", "hspace", "vspace",
                        "kern", "mkern", "mspace", "thinspace", "thickspace",
                        "enspace", "negthickspace", "negthinspace"):
                if i < n and tex[i] == '{':
                    _, i = _find_brace_group(tex, i)
                continue

            # Unknown command with brace argument — try to speak the content
            if i < n and tex[i] == '{':
                body, i = _find_brace_group(tex, i)
                body_spoken = _translate_latex(body).strip()
                if body_spoken:
                    out.append(f' {body_spoken} ')
                continue

            # Unknown bare command — speak it as a word
            out.append(f' {cmd} ')
            continue

        # --- Subscript ---
        if c == '_':
            i += 1
            body, i = _find_brace_group(tex, i)
            body_stripped = body.strip()
            # Common subscript words: read as a word, not letter by letter
            if re.match(r'^[a-zA-Z]{2,}$', body_stripped) and body_stripped.lower() not in _LATEX_GREEK:
                out.append(f' sub {body_stripped} ')
            else:
                body_spoken = _translate_latex(body).strip()
                if body_spoken:
                    out.append(f' sub {body_spoken} ')
            continue

        # --- Superscript ---
        if c == '^':
            i += 1
            body, i = _find_brace_group(tex, i)
            body_stripped = body.strip()
            # Check for common power patterns
            if body_stripped in _ORDINAL_SUFFIXES:
                out.append(f' {_ORDINAL_SUFFIXES[body_stripped]} ')
            elif body_stripped == "\\prime" or body_stripped == "'":
                out.append(' prime ')
            elif body_stripped == "\\dagger" or body_stripped == "†":
                out.append(' dagger ')
            elif body_stripped == "T":
                out.append(' transpose ')
            elif body_stripped == "*":
                out.append(' star ')
            else:
                body_spoken = _translate_latex(body).strip()
                out.append(f' to the power of {body_spoken} ')
            continue

        # --- Brace group (no preceding command) ---
        if c == '{':
            body, i = _find_brace_group(tex, i)
            out.append(f' {_translate_latex(body).strip()} ')
            continue
        if c == '}':
            i += 1
            continue

        # --- Bra-ket notation and vertical bars ---
        if c == '|':
            rest = tex[i + 1:]
            behind = ' '.join(out[-8:]) if len(out) >= 8 else ' '.join(out)
            has_rangle_ahead = bool(re.search(r'\\rangle', rest))
            has_bra_behind = 'bra' in behind

            # Inside bra-ket: \langle A | B | C \rangle
            if has_bra_behind and has_rangle_ahead:
                # This is a separator between bra content and operator/ket
                out.append(' , ')
                i += 1
                continue
            # End of bra: \langle A |  (no \rangle ahead, so bra is done)
            if has_bra_behind and not has_rangle_ahead:
                out.append(' , ')
                i += 1
                continue
            # Start of ket: | A \rangle
            if not has_bra_behind and has_rangle_ahead:
                out.append(' ket ')
                i += 1
                continue
            # Default: absolute value or general bar
            out.append(' absolute value of ')
            i += 1
            continue

        # --- Angle brackets (Unicode) ---
        if c == '⟨' or c == '\u27e8':
            out.append(' bra ')
            i += 1
            continue
        if c == '⟩' or c == '\u27e9':
            out.append(' ket ')
            i += 1
            continue

        # --- Standard operators as bare characters ---
        if c == '=':
            out.append(' equals ')
            i += 1
            continue
        if c == '+':
            out.append(' plus ')
            i += 1
            continue
        if c == '-':
            # Could be minus or negative sign
            out.append(' minus ')
            i += 1
            continue
        if c == '*':
            out.append(' times ')
            i += 1
            continue
        if c == '/':
            out.append(' divided by ')
            i += 1
            continue
        if c == '<':
            out.append(' less than ')
            i += 1
            continue
        if c == '>':
            out.append(' greater than ')
            i += 1
            continue
        if c == '!':
            out.append(' factorial ')
            i += 1
            continue
        if c == '~':
            out.append(' ')
            i += 1
            continue
        if c == '&':
            out.append(' ')
            i += 1
            continue
        if c == "'":
            out.append(' prime ')
            i += 1
            continue

        # --- Parentheses ---
        if c == '(':
            out.append(' open parenthesis ')
            i += 1
            continue
        if c == ')':
            out.append(' close parenthesis ')
            i += 1
            continue
        if c == '[':
            out.append(' open bracket ')
            i += 1
            continue
        if c == ']':
            out.append(' close bracket ')
            i += 1
            continue

        # --- Unicode math symbols (already present in text) ---
        _UNICODE_MAP = {
            '≠': 'is not equal to', '≤': 'is less than or equal to',
            '≥': 'is greater than or equal to', '≈': 'is approximately',
            '∞': 'infinity', '±': 'plus or minus', '×': 'times',
            '÷': 'divided by', '√': 'the square root of',
            '∑': 'the sum of', '∏': 'the product of',
            '∫': 'the integral of', '∬': 'the double integral of',
            '∭': 'the triple integral of', '∮': 'the contour integral of',
            '∂': 'the partial derivative of', '∇': 'the gradient of',
            '∈': 'is in', '∉': 'is not in', '⊂': 'is a subset of',
            '⊆': 'is a subset of or equal to', '⊃': 'is a superset of',
            '∩': 'intersection', '∪': 'union',
            '⇒': 'implies', '⇔': 'if and only if',
            '→': 'goes to', '←': 'comes from', '↔': 'is equivalent to',
            '∀': 'for all', '∃': 'there exists',
            '¬': 'not', '∧': 'and', '∨': 'or',
            '⊗': 'tensor product', '⊕': 'direct sum',
            '†': 'dagger', '′': 'prime', '″': 'double prime',
            '°': 'degrees', 'ℏ': 'h bar', 'ℓ': 'l',
            '·': 'times', '…': 'dot dot dot', '□': 'the d\'Alembertian of',
        }
        if c in _UNICODE_MAP:
            out.append(f' {_UNICODE_MAP[c]} ')
            i += 1
            continue

        # --- Digits: group consecutive digits into a number ---
        if c.isdigit():
            num_start = i
            while i < n and (tex[i].isdigit() or tex[i] == '.'):
                i += 1
            out.append(f' {tex[num_start:i]} ')
            continue

        # --- Regular characters (letters) ---
        out.append(c)
        i += 1

    return ' '.join(out)


DEFAULT_OPTIONS = {
    "remove_frontmatter": True,
    "remove_code_blocks": True,
    "remove_images": True,
    "remove_structural_index_block": True,
    "remove_media_callout_block": True,
    "process_tables": True,
    "table_mode": "narrative",  # narrative | strip | keep
    "process_latex_blocks": True,
    "math_label_enabled": True,
    "math_label_text": "Math translation:",
    "unknown_math_policy": "drop",  # drop | placeholder | keep
    "remove_markdown_links": False,
    "remove_wiki_links": False,
    "remove_raw_urls": True,
    "dedupe_link_text": True,
    "remove_hashtags": True,
    "remove_inline_code": True,
    "remove_callouts": True,
    "remove_highlights": True,
    "remove_footnotes": True,
    "remove_comments": True,
    "remove_html_tags": True,
    "replace_comparison_symbols": True,
    "comparison_symbol_map": {
        "<": "less than",
        ">": "greater than",
    },
    "remove_markdown": True,
    "normalize_symbols": True,
    "normalize_greek": True,
    "normalize_special_letters": True,
    "normalize_subscripts": True,
    "normalize_superscripts": True,
    "normalize_axiom_refs": True,
    "normalize_law_refs": True,
    "optimize_numbers": True,
    "dedupe_lines": True,
    "clean_whitespace": True,
}


class TheophysicsNormalizer:
    """
    Normalizes Theophysics-specific notation for TTS output.
    Handles: Greek letters, chi-field symbols, equations, axiom references, laws.
    """

    def __init__(
        self,
        ai_translator: Optional["AIMathTranslator"] = None,
        options: Optional[Dict] = None,
    ):
        self.ai_translator = ai_translator
        self.options = self._build_options(options)

        self.greek_lower = {
            "\u03b1": "alpha", "\u03b2": "beta", "\u03b3": "gamma", "\u03b4": "delta",
            "\u03b5": "epsilon", "\u03b6": "zeta", "\u03b7": "eta", "\u03b8": "theta",
            "\u03b9": "iota", "\u03ba": "kappa", "\u03bb": "lambda", "\u03bc": "mu",
            "\u03bd": "nu", "\u03be": "xi", "\u03bf": "omicron", "\u03c0": "pi",
            "\u03c1": "rho", "\u03c3": "sigma", "\u03c4": "tau", "\u03c5": "upsilon",
            "\u03c6": "phi", "\u03c7": "chi", "\u03c8": "psi", "\u03c9": "omega",
            "\u03c2": "sigma",
        }
        self.greek_upper = {
            "\u0391": "Alpha", "\u0392": "Beta", "\u0393": "Gamma", "\u0394": "Delta",
            "\u0395": "Epsilon", "\u0396": "Zeta", "\u0397": "Eta", "\u0398": "Theta",
            "\u0399": "Iota", "\u039a": "Kappa", "\u039b": "Lambda", "\u039c": "Mu",
            "\u039d": "Nu", "\u039e": "Xi", "\u039f": "Omicron", "\u03a0": "Pi",
            "\u03a1": "Rho", "\u03a3": "Sigma", "\u03a4": "Tau", "\u03a5": "Upsilon",
            "\u03a6": "Phi", "\u03a7": "Chi", "\u03a8": "Psi", "\u03a9": "Omega",
        }

        self.theophysics_symbols = {
            "chi-field": "chi field",
            "\u221e": "infinity",
            "\u2192": "approaches",
            "\u2190": "comes from",
            "\u2194": "is equivalent to",
            "\u21d2": "implies",
            "\u21d4": "if and only if",
            "\u2248": "approximately equals",
            "\u2261": "is identically equal to",
            "\u2260": "is not equal to",
            "\u2264": "is less than or equal to",
            "\u2265": "is greater than or equal to",
            "\u2103": "degrees Celsius",
            "\u2109": "degrees Fahrenheit",
            "\u00b0": "degrees",
        }

        self.special_letters = {
            "\U0001d530": "s",
            "\u210f": "h-bar",
            "\u2112": "L",
            "\u2202": "partial",
        }

        self.subscripts = {
            "\u2080": " sub zero ", "\u2081": " sub one ", "\u2082": " sub two ",
            "\u2083": " sub three ", "\u2084": " sub four ", "\u2085": " sub five ",
            "\u2086": " sub six ", "\u2087": " sub seven ", "\u2088": " sub eight ",
            "\u2089": " sub nine ", "\u2090": " sub a ", "\u2091": " sub e ",
            "\u2092": " sub o ", "\u2093": " sub x ", "\u1d62": " sub i ",
            "\u2c7c": " sub j ", "\u2096": " sub k ", "\u2097": " sub l ",
            "\u2098": " sub m ", "\u2099": " sub n ", "\u209a": " sub p ",
            "\u209b": " sub s ", "\u209c": " sub t ",
        }

        self.superscripts = {
            "\u2070": " to the zero ", "\u00b9": " to the one ",
            "\u00b2": " squared ", "\u00b3": " cubed ",
            "\u2074": " to the fourth ", "\u2075": " to the fifth ",
            "\u2076": " to the sixth ", "\u2077": " to the seventh ",
            "\u2078": " to the eighth ", "\u2079": " to the ninth ",
            "\u207f": " to the n ", "\u2071": " to the i ",
        }

        self.axiom_pattern = re.compile(r"\bA(\d{1,3})\b")
        self.law_pattern = re.compile(r"\bL(\d{1,2})\b")

        self.math_translations = self.load_math_translations()

    def _build_options(self, options: Optional[Dict]) -> Dict:
        merged = dict(DEFAULT_OPTIONS)
        if not options:
            return merged

        for key, value in options.items():
            if key == "comparison_symbol_map" and isinstance(value, dict):
                merged[key] = {**merged[key], **value}
            else:
                merged[key] = value
        return merged

    def _enabled(self, key: str) -> bool:
        return bool(self.options.get(key, False))

    def remove_code_blocks(self, text: str) -> str:
        text = re.sub(r"```[\w]*\n[\s\S]*?```", "", text)
        text = re.sub(r"~~~[\w]*\n[\s\S]*?~~~", "", text)
        return text

    def remove_images(self, text: str) -> str:
        text = re.sub(r"!\[\[([^\]]+)\]\]", "", text)
        text = re.sub(r"!\[([^\]]*)\]\([^)]+\)", "", text)
        text = re.sub(r"<img[^>]*>", "", text)
        return text

    def remove_inline_code(self, text: str) -> str:
        return re.sub(r"`([^`]+)`", r"\1", text)

    def remove_hashtags(self, text: str) -> str:
        text = re.sub(r"(?:\s+#\w+)+$", "", text, flags=re.MULTILINE)
        text = re.sub(r"#(\w+)", r"\1", text)
        return text

    def remove_markdown_links(self, text: str) -> str:
        keep_text = bool(self.options.get("keep_markdown_link_text", True))
        if keep_text:
            return re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
        return re.sub(r"\[[^\]]+\]\([^)]+\)", "", text)

    def remove_wiki_links(self, text: str) -> str:
        keep_text = bool(self.options.get("keep_wiki_link_text", True))
        if keep_text:
            text = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", text)
            text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)
            return text
        text = re.sub(r"\[\[[^\]]+\]\]", "", text)
        return text

    def remove_raw_urls(self, text: str) -> str:
        text = re.sub(r"https?://[^\s]+", "", text)
        text = re.sub(r"ftp://[^\s]+", "", text)
        text = re.sub(r"www\.[^\s]+", "", text)
        text = re.sub(r"\S+@\S+\.\S+", "", text)
        return text

    def dedupe_lines(self, text: str) -> str:
        lines = text.splitlines()
        out = []
        prev = ""
        for line in lines:
            norm = re.sub(r"\s+", " ", line).strip().lower()
            if norm and norm == prev:
                continue
            out.append(line)
            prev = norm
        return "\n".join(out)

    def dedupe_immediate_phrases(self, text: str) -> str:
        pattern = re.compile(r"\b([A-Za-z][A-Za-z0-9\- ]{1,60})\s+\1\b", re.IGNORECASE)
        prev = None
        cur = text
        while prev != cur:
            prev = cur
            cur = pattern.sub(r"\1", cur)
        return cur

    def remove_callouts(self, text: str) -> str:
        # Keep callout content, remove Obsidian marker prefix.
        return re.sub(r"^\s*>\s*\[![^\]]+\]\s*", "", text, flags=re.MULTILINE)

    def remove_named_callout_blocks(self, text: str) -> str:
        """
        Remove metadata-heavy callout blocks that should not be narrated in TTS:
        - Structural Index callout ([!abstract]- ... Structural Index ...)
        - Media callout ([!info]- ... Listen, Watch and Download ...)
        - Explicit MEDIA_CALLOUT markers if present
        """
        lines = text.splitlines()
        out: List[str] = []
        i = 0

        while i < len(lines):
            line = lines[i]
            lower = line.lower()

            if self._enabled("remove_media_callout_block") and "<!-- media_callout_start -->" in lower:
                i += 1
                while i < len(lines) and "<!-- media_callout_end -->" not in lines[i].lower():
                    i += 1
                if i < len(lines):
                    i += 1
                while i < len(lines) and not lines[i].strip():
                    i += 1
                continue

            if (
                self._enabled("remove_structural_index_block")
                and re.match(r"^\s*>\s*\[!abstract\]", line, flags=re.IGNORECASE)
                and "structural index" in lower
            ):
                i += 1
                while i < len(lines):
                    candidate = lines[i]
                    if re.match(r"^\s*>", candidate):
                        i += 1
                        continue
                    if not candidate.strip():
                        i += 1
                        continue
                    break
                continue

            if (
                self._enabled("remove_media_callout_block")
                and re.match(r"^\s*>\s*\[!info\]", line, flags=re.IGNORECASE)
                and (
                    "listen, watch and download" in lower
                    or "listen, watch & download" in lower
                )
            ):
                i += 1
                while i < len(lines):
                    candidate = lines[i]
                    if re.match(r"^\s*>", candidate):
                        i += 1
                        continue
                    if not candidate.strip():
                        i += 1
                        continue
                    break
                continue

            out.append(line)
            i += 1

        return "\n".join(out)

    def remove_footnotes(self, text: str) -> str:
        # Remove definition lines first so labels are still present for matching.
        text = re.sub(r"^\[\^[^\]]+\]:.*$", "", text, flags=re.MULTILINE)
        text = re.sub(r"^\s{2,}.*$", "", text, flags=re.MULTILINE)
        text = re.sub(r"\[\^[^\]]+\]", "", text)
        return text

    def remove_comments(self, text: str) -> str:
        text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)
        # Keep %%tts ... %% blocks; remove other Obsidian comments.
        text = re.sub(r"%%(?!tts).*?%%", "", text, flags=re.DOTALL | re.IGNORECASE)
        return text

    def remove_html_tags(self, text: str) -> str:
        return re.sub(r"<[^>]+>", " ", text)

    def replace_comparison_symbols(self, text: str) -> str:
        sym = self.options.get("comparison_symbol_map", {})

        lt_word = sym.get("<", "less than")
        gt_word = sym.get(">", "greater than")

        text = re.sub(r"(?<=\S)\s*<\s*(?=\S)", f" {lt_word} ", text)
        text = re.sub(r"(?<=\S)\s*>\s*(?=\S)", f" {gt_word} ", text)
        return text

    def load_math_translations(self) -> Dict[str, str]:
        mapping = {}
        script_dir = os.path.dirname(__file__)
        parent_dir = os.path.dirname(script_dir)
        candidates = [
            "MATH_TRANSLATION_MASTER_FIXED.xlsx",
            os.path.join(script_dir, "MATH_TRANSLATION_MASTER_FIXED.xlsx"),
            "MATH_TRANSLATION_MASTER.xlsx",
            os.path.join(script_dir, "MATH_TRANSLATION_MASTER.xlsx"),
            os.path.join(parent_dir, "config", "MATH_TRANSLATION_MASTER.xlsx"),
            os.path.join(parent_dir, "MATH_TRANSLATION_MASTER.xlsx"),
        ]

        file_path = None
        for path in candidates:
            if os.path.exists(path):
                file_path = path
                break

        if not file_path:
            print("[WARN] MATH_TRANSLATION_MASTER.xlsx not found. Equations will be skipped.")
            return mapping

        try:
            print(f"[INFO] Loading math translations from: {file_path}")
            df = pd.read_excel(file_path)

            latex_col = "latex"
            audio_col = "tts_audio"

            if latex_col not in df.columns or audio_col not in df.columns:
                print(f"[ERROR] Master file missing required columns: {latex_col}, {audio_col}")
                return mapping

            for _, row in df.iterrows():
                latex = str(row[latex_col]).strip()
                audio = str(row[audio_col]).strip()
                latex_norm = re.sub(r"\s+", " ", latex)
                latex_no_space = re.sub(r"\s+", "", latex)

                if latex and audio and audio.lower() != "nan":
                    mapping[latex] = audio
                    mapping[latex_norm] = audio
                    mapping[latex_no_space] = audio

            print(f"[INFO] Loaded {len(mapping)} math translation pairs from master file.")

        except Exception as e:
            print(f"[ERROR] Failed to load math translations: {e}")

        return mapping

    def find_equation_translation(self, equation: str) -> str:
        clean_eq = equation.replace("$", "").strip()
        normalized = re.sub(r"\s+", " ", clean_eq)
        no_spaces = re.sub(r"\s+", "", clean_eq)

        if clean_eq in self.math_translations:
            return self.math_translations[clean_eq]
        if normalized in self.math_translations:
            return self.math_translations[normalized]
        if no_spaces in self.math_translations:
            return self.math_translations[no_spaces]

        return self.generate_equation_fallback(clean_eq)

    def generate_equation_fallback(self, equation: str) -> str:
        """Full LaTeX-to-speech translation for any equation not in the lookup table."""
        return latex_to_speech(equation)

    def process_latex_blocks(self, text: str) -> str:
        unknown_policy = str(self.options.get("unknown_math_policy", "drop")).lower()
        label_enabled = bool(self.options.get("math_label_enabled", True))
        label_text = str(self.options.get("math_label_text", "Math translation:")).strip()

        def replace_match(match):
            content = match.group(0)
            inner = match.group(1) if match.groups() else match.group(0)
            clean_inner = inner.replace("$", "").strip()
            is_display_math = content.startswith("$$") and content.endswith("$$")

            if re.match(r"^\s*\$?\d+[\d,\.]*\s*$", clean_inner):
                return content

            if len(clean_inner.strip()) <= 1:
                single_char = clean_inner.strip().lower()
                if single_char in self.greek_lower:
                    return f" {self.greek_lower[single_char]} "
                return content

            translation = self.find_equation_translation(clean_inner)
            if translation:
                if label_enabled:
                    return f" {label_text} {translation}. "
                return f" {translation} "

            if unknown_policy == "keep":
                return content
            if unknown_policy == "placeholder":
                return " mathematical expression "
            if is_display_math:
                return ""
            return ""

        text = re.sub(r"\$\$(.*?)\$\$", replace_match, text, flags=re.DOTALL)
        text = re.sub(r"(?<!\$)\$(?!\$)(.*?)(?<!\$)\$", replace_match, text)
        return text

    def detect_markdown_table(self, text: str) -> List[Tuple[int, int, str]]:
        tables = []
        lines = text.split("\n")
        i = 0

        while i < len(lines):
            line = lines[i].strip()
            if "|" in line and (line.startswith("|") or line.count("|") >= 2):
                table_start = i
                table_lines = [lines[i]]
                i += 1

                while i < len(lines):
                    candidate = lines[i].strip()
                    if "|" in candidate and (candidate.startswith("|") or candidate.count("|") >= 2):
                        table_lines.append(lines[i])
                        i += 1
                    elif candidate == "":
                        if i + 1 < len(lines) and "|" in lines[i + 1]:
                            table_lines.append(lines[i])
                            i += 1
                        else:
                            break
                    else:
                        break

                if len(table_lines) >= 2:
                    tables.append((table_start, i, "\n".join(table_lines)))
            else:
                i += 1

        return tables

    def _split_table_row(self, line: str) -> List[str]:
        row = line.strip()
        if row.startswith("|"):
            row = row[1:]
        if row.endswith("|"):
            row = row[:-1]
        return [cell.strip() for cell in row.split("|")]

    def parse_markdown_table(self, table_text: str) -> Tuple[List[str], List[List[str]]]:
        lines = [line for line in table_text.split("\n") if line.strip()]
        if not lines:
            return [], []

        headers = self._split_table_row(lines[0])

        data_start = 1
        if len(lines) > 1 and re.match(r"^[\s\|:\-]+$", lines[1].strip()):
            data_start = 2

        rows: List[List[str]] = []
        for line in lines[data_start:]:
            if "|" not in line:
                continue
            cells = self._split_table_row(line)
            if not any(cells):
                continue
            if len(cells) < len(headers):
                cells.extend([""] * (len(headers) - len(cells)))
            rows.append(cells[: len(headers)] if headers else cells)

        return headers, rows

    def table_to_narrative(self, table_text: str) -> str:
        headers, rows = self.parse_markdown_table(table_text)
        if not rows:
            return ""

        narratives: List[str] = []
        for idx, row in enumerate(rows, start=1):
            parts = []
            for col_idx, cell in enumerate(row):
                if not cell:
                    continue
                header = headers[col_idx] if col_idx < len(headers) and headers[col_idx] else f"column {col_idx + 1}"
                parts.append(f"{header} is {cell}")
            if parts:
                narratives.append(f"Row {idx}: " + "; ".join(parts) + ".")

        if not narratives:
            return ""

        return "\n".join(narratives)

    def process_tables(self, text: str) -> str:
        mode = str(self.options.get("table_mode", "narrative")).lower()
        if mode == "keep":
            return text

        tables = self.detect_markdown_table(text)
        if not tables:
            return text

        lines = text.split("\n")
        for start_line, end_line, table_text in reversed(tables):
            if mode == "strip":
                replacement_lines = [""]
            else:
                narrative = self.table_to_narrative(table_text)
                replacement_lines = ["", "Table summary:", narrative, ""] if narrative else [""]
            lines[start_line:end_line] = replacement_lines

        return "\n".join(lines)

    def optimize_numbers_for_tts(self, text: str) -> str:
        text = re.sub(r"(\d)%", r"\1 percent", text)
        text = re.sub(r"\b(\d+),?000,?000\b", r"\1 million", text)
        text = re.sub(r"\b(\d+),?000\b", r"\1 thousand", text)
        return text

    def extract_tts_blocks(self, text: str) -> Tuple[str, List[str]]:
        tts_pattern = re.compile(r"%%tts\s*(.*?)\s*%%", re.DOTALL | re.IGNORECASE)
        tts_blocks = tts_pattern.findall(text)
        text_with_markers = tts_pattern.sub("<<TTS_BLOCK>>", text)
        return text_with_markers, tts_blocks

    def reinsert_tts_blocks(self, text: str, tts_blocks: List[str]) -> str:
        for block in tts_blocks:
            text = text.replace("<<TTS_BLOCK>>", block.strip(), 1)
        return text.replace("<<TTS_BLOCK>>", "")

    def normalize_greek(self, text: str) -> str:
        for greek, spoken in {**self.greek_lower, **self.greek_upper}.items():
            text = text.replace(greek, f" {spoken} ")
        return text

    def normalize_special_letters(self, text: str) -> str:
        for letter, spoken in self.special_letters.items():
            text = text.replace(letter, f" {spoken} ")
        return text

    def normalize_symbols(self, text: str) -> str:
        for symbol, spoken in self.theophysics_symbols.items():
            text = text.replace(symbol, f" {spoken} ")
        return text

    def normalize_subscripts(self, text: str) -> str:
        for sub, spoken in self.subscripts.items():
            text = text.replace(sub, spoken)
        return text

    def normalize_superscripts(self, text: str) -> str:
        for sup, spoken in self.superscripts.items():
            text = text.replace(sup, spoken)
        return text

    def normalize_axiom_refs(self, text: str) -> str:
        def replace_axiom(match):
            return f" Axiom {match.group(1)} "

        return self.axiom_pattern.sub(replace_axiom, text)

    def normalize_law_refs(self, text: str) -> str:
        law_names = {
            "1": "Law 1, Unity", "2": "Law 2, Duality", "3": "Law 3, Trinity",
            "4": "Law 4, Quaternary Foundation", "5": "Law 5, Quintessence",
            "6": "Law 6, Hexadic Harmony", "7": "Law 7, Septenary Completion",
            "8": "Law 8, Octave Recursion", "9": "Law 9, Ennead Fulfillment",
            "10": "Law 10, Decadic Totality",
        }

        def replace_law(match):
            num = match.group(1)
            return f" {law_names.get(num, f'Law {num}')} "

        return self.law_pattern.sub(replace_law, text)

    def remove_yaml_frontmatter(self, text: str) -> str:
        if text.startswith("---"):
            lines = text.split("\n")
            in_frontmatter = False
            frontmatter_end = -1

            for i, line in enumerate(lines):
                stripped = line.strip()
                if stripped == "---":
                    if not in_frontmatter:
                        in_frontmatter = True
                    else:
                        frontmatter_end = i
                        break

            if frontmatter_end > 0:
                text = "\n".join(lines[frontmatter_end + 1 :])

        text = re.sub(r"^[*]{3,}\s*\n(?:.*?\n)*?[*]{3,}\s*\n", "", text, flags=re.MULTILINE)
        text = re.sub(r"^[+]{3,}\s*\n(?:.*?\n)*?[+]{3,}\s*\n", "", text, flags=re.MULTILINE)
        return text.strip()

    def remove_markdown(self, text: str) -> str:
        if self._enabled("remove_highlights"):
            text = re.sub(r"==([^=]+)==", r"\1", text)

        text = re.sub(r"^#{1,6}\s*", "", text, flags=re.MULTILINE)
        text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
        text = re.sub(r"\*([^*]+)\*", r"\1", text)
        text = re.sub(r"__([^_]+)__", r"\1", text)
        text = re.sub(r"_([^_]+)_", r"\1", text)
        text = re.sub(r"`([^`]+)`", r"\1", text)
        text = re.sub(r"```[^`]*```", "", text, flags=re.DOTALL)

        # list/callout quote markers while preserving readable content
        text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)
        text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)
        text = re.sub(r"^>\s*", "", text, flags=re.MULTILINE)
        return text

    def clean_whitespace(self, text: str) -> str:
        text = re.sub(r"\n{3,}", "\n\n", text)
        text = re.sub(r" {2,}", " ", text)
        text = re.sub(r"\s+([.,!?;:])", r"\1", text)
        return text.strip()

    def normalize(self, text: str) -> str:
        if self._enabled("remove_frontmatter"):
            text = self.remove_yaml_frontmatter(text)

        text_with_markers, tts_blocks = self.extract_tts_blocks(text)

        if self._enabled("remove_code_blocks"):
            text_with_markers = self.remove_code_blocks(text_with_markers)
        if self._enabled("remove_images"):
            text_with_markers = self.remove_images(text_with_markers)
        if self._enabled("remove_structural_index_block") or self._enabled("remove_media_callout_block"):
            text_with_markers = self.remove_named_callout_blocks(text_with_markers)
        if self._enabled("remove_callouts"):
            text_with_markers = self.remove_callouts(text_with_markers)
        if self._enabled("remove_footnotes"):
            text_with_markers = self.remove_footnotes(text_with_markers)
        if self._enabled("remove_comments"):
            text_with_markers = self.remove_comments(text_with_markers)

        if self._enabled("process_tables"):
            text_with_markers = self.process_tables(text_with_markers)

        # Apply pre-LaTeX transforms: units, derivatives, references,
        # theology terms, framework vocabulary
        text_with_markers = apply_pre_latex_transforms(text_with_markers)

        if self._enabled("process_latex_blocks"):
            text_with_markers = self.process_latex_blocks(text_with_markers)

        if self._enabled("remove_markdown_links"):
            text_with_markers = self.remove_markdown_links(text_with_markers)
        if self._enabled("remove_wiki_links"):
            text_with_markers = self.remove_wiki_links(text_with_markers)
        if self._enabled("remove_raw_urls"):
            text_with_markers = self.remove_raw_urls(text_with_markers)

        if self._enabled("dedupe_link_text"):
            text_with_markers = self.dedupe_immediate_phrases(text_with_markers)

        if self._enabled("remove_hashtags"):
            text_with_markers = self.remove_hashtags(text_with_markers)
        if self._enabled("remove_inline_code"):
            text_with_markers = self.remove_inline_code(text_with_markers)
        if self._enabled("remove_html_tags"):
            text_with_markers = self.remove_html_tags(text_with_markers)
        if self._enabled("replace_comparison_symbols"):
            text_with_markers = self.replace_comparison_symbols(text_with_markers)
        if self._enabled("remove_markdown"):
            text_with_markers = self.remove_markdown(text_with_markers)

        text = self.reinsert_tts_blocks(text_with_markers, tts_blocks)

        if self._enabled("normalize_symbols"):
            text = self.normalize_symbols(text)
        if self._enabled("normalize_greek"):
            text = self.normalize_greek(text)
        if self._enabled("normalize_special_letters"):
            text = self.normalize_special_letters(text)
        if self._enabled("normalize_subscripts"):
            text = self.normalize_subscripts(text)
        if self._enabled("normalize_superscripts"):
            text = self.normalize_superscripts(text)
        if self._enabled("normalize_axiom_refs"):
            text = self.normalize_axiom_refs(text)
        if self._enabled("normalize_law_refs"):
            text = self.normalize_law_refs(text)
        if self._enabled("optimize_numbers"):
            text = self.optimize_numbers_for_tts(text)
        if self._enabled("dedupe_lines"):
            text = self.dedupe_lines(text)
        if self._enabled("clean_whitespace"):
            text = self.clean_whitespace(text)

        return text


_normalizer = None


def get_normalizer() -> TheophysicsNormalizer:
    global _normalizer
    if _normalizer is None:
        _normalizer = TheophysicsNormalizer()
    return _normalizer


def normalize_for_tts(text: str) -> str:
    return get_normalizer().normalize(text)


if __name__ == "__main__":
    test_document = """
# Theophysics Update
Here is an equation: $\\Delta E_{\\text{required}} = T \\cdot \\Delta S$.
And another: $$ \\chi = \\iiint (G \\cdot M) dt $$
A table:
| Variable | Value |
| --- | --- |
| Axiom | A42 |
| Ratio | 3/7 |
"""
    normalizer = TheophysicsNormalizer()
    print(normalizer.normalize(test_document))
