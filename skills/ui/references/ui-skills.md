---
name: ui-skills-summary
description: "Summary of UI Skills constraint set (implementation quality first)"
---

# UI Skills Summary

Constraint set to prevent common failure points in UI implementation.

## Stack
- MUST: Use Tailwind CSS default values (exceptions only for existing custom values or explicit requests)
- MUST: Use `motion/react` for JavaScript animations
- SHOULD: Use `tw-animate-css` for Tailwind entry/minor animations
- MUST: Use `cn` (`clsx` + `tailwind-merge`) for class control

## Components
- MUST: Use accessible primitives for keyboard/focus behavior
- MUST: Prefer existing primitives
- NEVER: Mix primitives on the same interaction surface
- SHOULD: Prefer Base UI when compatible
- MUST: Icon-only buttons must have `aria-label`
- NEVER: Handroll keyboard/focus behavior (unless explicitly requested)

## Interaction
- MUST: Use AlertDialog for destructive actions
- SHOULD: Use structural skeletons for loading states
- NEVER: Use `h-screen`; use `h-dvh` instead
- MUST: Account for `safe-area-inset` on fixed elements
- MUST: Display errors near the point of interaction
- NEVER: Block paste in input/textarea

## Animation
- NEVER: Do not add animations unless explicitly requested
- MUST: Animate only `transform` / `opacity`
- NEVER: Animate `width/height/top/left/margin/padding`
- SHOULD: Animate `background/color` only for small, localized UI elements
- SHOULD: Use `ease-out` for entry
- NEVER: Feedback animations must not exceed 200ms
- MUST: Stop loops when off-screen
- SHOULD: Respect `prefers-reduced-motion`
- NEVER: Custom easing is prohibited unless explicitly requested
- SHOULD: Avoid animating large images or full-bleed surfaces

## Typography
- MUST: Use `text-balance` for headings
- MUST: Use `text-pretty` for body text
- MUST: Use `tabular-nums` for numeric values
- SHOULD: Use `truncate` or `line-clamp` for dense UI
- NEVER: Do not change `tracking-*` arbitrarily

## Layout
- MUST: Use a fixed `z-index` scale (avoid arbitrary `z-*` values)
- SHOULD: Use `size-*` for square elements

## Performance
- NEVER: Do not animate large `blur()` / `backdrop-filter`
- NEVER: Do not apply `will-change` persistently
- NEVER: Write in render what doesn't need to be in `useEffect`

## Design
- NEVER: Gradients are prohibited unless explicitly requested
- NEVER: Purple/multi-color gradients are prohibited
- NEVER: Do not use glow as a primary affordance
- SHOULD: Use Tailwind's default shadow scale
- MUST: Empty states must present exactly one "next action"
- SHOULD: Use a single accent color
- SHOULD: Prefer existing theme/tokens over introducing new colors

## Sources
- https://www.ui-skills.com/
- https://agent-skills.xyz/skills/baptistearno-typebot-io-ui-skills
