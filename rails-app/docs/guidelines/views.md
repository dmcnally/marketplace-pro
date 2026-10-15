# View Guidelines

- Keep views presentation-only. Do not perform permission checks, role checks, ownership checks, or other authorization conditionals in templates.
- Anything that requires a permission check should be contained in an action, with authorization enforced outside the view.
- View conditionals are acceptable for simple presentation logic, but avoid using them for business decisions. Prefer preparing explicit render state before the template is rendered.
- Do not add Tailwind utility classes unless the project explicitly uses Tailwind.
- Use BEM naming conventions for CSS classes:
  - Block: `.block-name`
  - Element: `.block-name__element`
  - Modifier: `.block-name--modifier`
- Keep CSS organized as component-oriented files.
- Use semantic class names and include hover/focus states where relevant.
