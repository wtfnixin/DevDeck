# Taste Skill: Complete Guide & Usage Manual

> **Repository**: [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill)  
> **Status**: Successfully downloaded and installed into your agent skills library (both globally and locally in `.agents/skills`).

---

## 1. What is Taste Skill?

**Taste Skill** is an open-source, anti-slop frontend and design framework specifically engineered for AI coding agents (Claude, Codex, Cursor, Gemini, GPT). 

Standard AI coding assistants tend to produce generic, predictable, and boilerplate-looking interfaces—often referred to as **"AI Slop"**:
* Uniform centered heroes over generic dark mesh gradients.
* Repetitive 3-column feature cards with purple/blue glowing borders.
* Inter font paired with slate-900 backgrounds and generic glassmorphism on every container.
* Unresponsive, floaty hover micro-animations with zero intentional hierarchy.

**Taste Skill fixes this** by equipping AI agents with professional design guidelines, opinionated visual systems, customizable design dials, and reference-generation pipelines.

---

## 2. Complete Catalog of Skills (All 13 Included)

Taste Skill is a modular suite consisting of **code implementation skills** and **image reference skills**:

### Implementation & Code Skills (Outputs Production Code)

| Skill Name | Install Identifier | Purpose & Focus |
| :--- | :--- | :--- |
| **taste-skill** | `design-taste-frontend` | 🌟 **v2 (Main Core Skill)**: Reads the user's brief, infers design direction, configures 3 design dials (Variance / Motion / Density), applies anti-slop typography & layout, and enforces pre-flight checks. |
| **taste-skill-v1** | `design-taste-frontend-v1` | **Legacy v1**: The original version of taste-skill preserved for existing projects requiring exact backward compatibility. |
| **gpt-tasteskill** | `gpt-taste` | **GPT/Codex Stricter Variant**: Enforces higher layout variance, aggressive GSAP motion direction, and strict anti-repetition rules. |
| **image-to-code-skill** | `image-to-code` | **Image ➔ Analyze ➔ Code Pipeline**: Guides the agent to first generate or inspect design mockups, deconstruct design tokens, and write matching code. |
| **redesign-skill** | `redesign-existing-projects` | **Existing Codebases**: Audits an existing frontend UI first, identifies visual debt, and iteratively refactors layout, typography, and spacing without breaking logic. |
| **minimalist-skill** | `minimalist-ui` | **Editorial / Linear Vibe**: Clean, structured product UI with restrained color palettes, high typographic contrast, and subtle motion. |
| **soft-skill** | `high-end-visual-design` | **Luxury & Calm Aesthetics**: Generous whitespace, muted palette, premium serif/sans pairings, and gentle spring physics animations. |
| **brutalist-skill** | `industrial-brutalist-ui` | **Industrial / Neo-Brutalist**: Sharp contrasts, heavy black borders, monospace/grotesk typography, and mechanical layouts. |
| **output-skill** | `full-output-enforcement` | **Anti-Truncation Guard**: Prevents the agent from leaving `// TODO: add remaining code here` or shipping half-finished components. |
| **stitch-skill** | `stitch-design-taste` | **Google Stitch Compatible**: Implements Google Stitch design rules and exports structured `DESIGN.md` tokens. |

### Reference & Image Generation Skills (Outputs Design Boards)

| Skill Name | Install Identifier | Purpose & Focus |
| :--- | :--- | :--- |
| **imagegen-frontend-web** | `imagegen-frontend-web` | Generates detailed web prompt mockups (hero, landing, multi-section comps) with art-directed typography and layout. |
| **imagegen-frontend-mobile** | `imagegen-frontend-mobile` | Generates mobile app screen flows and UX compositions across iOS and Android. |
| **brandkit** | `brandkit` | Generates complete brand identity boards: color palettes, typography scales, logo directions, and application mockups. |

---

## 3. How to Use Taste Skill

Because the skills are now installed in your workspace (`.agents/skills/`) and global configuration (`C:\Users\NITIN\.gemini\config\skills/`), you and your AI agent can invoke them anytime.

### Workflow 1: Building a New Web App or Page
Simply mention `taste-skill` in your prompt:
```text
"Build a landing page for our new developer productivity tool using taste-skill."
```
The agent will automatically:
1. Perform a **Brief Inference**: Determine the target audience, page type, and visual tone.
2. Output a one-line **Design Read**:
   > *"Reading this as: Developer tools landing page for technical power users, with a Linear-style minimalist language, leaning toward dark mode + JetBrains Mono/Geist + restrained motion."*
3. Set the **Three Core Dials** and generate premium, non-templated code.

---

### Workflow 2: Fine-Tuning with the Three Core Dials
In `taste-skill`, every design decision is controlled by three numbers (rated from 1 to 10):

1. **`DESIGN_VARIANCE` (1 to 10)**:
   * `1`: Completely symmetrical, traditional grid.
   * `8` *(Default)*: Asymmetrical, dynamic editorial layouts, modern pacing.
   * `10`: Experimental, artsy, Awwwards-style chaos.
2. **`MOTION_INTENSITY` (1 to 10)**:
   * `1`: Fully static (zero animations).
   * `6` *(Default)*: Smooth hover transitions, scroll reveal, polished micro-interactions.
   * `10`: Cinematic, physics-based springs, magnetic cursors, complex timeline animations.
3. **`VISUAL_DENSITY` (1 to 10)**:
   * `1`: Art gallery (huge whitespace, single focal points).
   * `4` *(Default)*: Balanced marketing site.
   * `10`: Bloomberg Terminal / dense IDE dashboard (high data density per viewport).

**Prompt Example**:
```text
"Build a portfolio using taste-skill. Set DESIGN_VARIANCE: 9, MOTION_INTENSITY: 8, VISUAL_DENSITY: 3."
```

---

### Workflow 3: Redesigning an Existing Page (`redesign-skill`)
When you already have a UI that looks outdated or generic:
```text
"Redesign our settings and dashboard page using redesign-skill. First audit the existing UI, identify spacing/hierarchy issues, then implement the updated version."
```

---

### Workflow 4: Image-to-Code Pipeline (`image-to-code-skill`)
When starting from a screenshot, Figma export, or concept image:
```text
"Follow image-to-code-skill: analyze this reference screenshot, extract the color palette, typography scale, and layout structure, then build the code to match."
```

---

## 4. Key Benefits of Using Taste Skill

### 🚫 1. Eradicates AI Slop
Eliminates repetitive AI design clichés (purple gradients, generic glassmorphism cards, Inter on slate-900). Forces deliberate font choices, curated palettes, and varied section rhythms.

### 📐 2. Contextual & Audience-Aware
Rather than applying a rigid template, Taste Skill reads the room first. A B2B enterprise procurement portal will receive clean, accessible, high-trust styling, while a creative designer portfolio will receive kinetic typography and expressive layout.

### 🎛️ 3. Predictable Control via Dials
You don't need to write long paragraphs explaining how much animation or spacing you want. Tweak the three numbers (`DESIGN_VARIANCE`, `MOTION_INTENSITY`, `VISUAL_DENSITY`) to adjust the feel instantly.

### ⚡ 4. Real Code Architecture
Includes battle-tested patterns for:
* **Tailwind CSS & Vanilla CSS**: Tokenized variables, fluid typography (`clamp()`), and proper contrast ratios.
* **Modern Motion**: Canonical GSAP timeline skeletons, CSS scroll-driven animations, and reduced-motion fallbacks for accessibility.

---

## 5. Summary Cheat Sheet

| I want to... | Use this Skill |
| :--- | :--- |
| Build a brand new premium landing page or web app | `taste-skill` |
| Overhaul an existing ugly or boilerplate UI | `redesign-skill` |
| Build a clean, high-density, Linear/Notion-style tool | `minimalist-skill` |
| Build an expensive, calm, high-end consumer product UI | `soft-skill` |
| Build a bold, brutalist, high-contrast engineering site | `brutalist-skill` |
| Replicate a visual reference image in code | `image-to-code-skill` |
| Prevent the AI from truncating or skipping code | `output-skill` |
