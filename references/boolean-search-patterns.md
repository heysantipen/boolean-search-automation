# Boolean Search Patterns by Role Type

Ready-to-use query strings for `boolean-search-config.json`. Copy the patterns that match your role, replace the title placeholders if needed, and paste into the `string` field.

Each ATS has slightly different URL patterns, so queries are grouped by platform.

---

## How to Use These

1. Pick the role type that matches yours
2. Copy the query strings for the platforms you want to cover
3. Paste into `boolean-search-config.json` under the `queries` array
4. Adjust the role title variants to match your actual target titles

**Tip:** Start with Greenhouse + Lever (one combined query) and Workday. Add Ashby — it's growing fast among startups and often has postings that don't appear elsewhere. ICIMS rounds out enterprise coverage. Between these four you'll cover the majority of B2B SaaS and tech job postings.

---

## Product Marketing Manager

### Greenhouse + Lever (combined)
```
(site:greenhouse.io OR site:lever.co) ("product marketing manager" OR "senior product marketing manager" OR "staff product marketing manager" OR "senior PMM") ("remote" OR "remote-first") ("US" OR "United States")
```

### Greenhouse + Lever (GTM / positioning focused)
```
(site:greenhouse.io OR site:lever.co) ("product marketing" OR "go-to-market" OR "GTM strategy") ("positioning" OR "messaging" OR "sales enablement") ("remote")
```

### Workday
```
site:myworkdayjobs.com ("product marketing manager" OR "senior product marketing manager") ("remote" OR "remote-first")
```

### ICIMS
```
site:careers.icims.com ("product marketing manager" OR "senior product marketing manager") ("remote")
```

### Ashby
```
site:jobs.ashbyhq.com ("product marketing manager" OR "senior product marketing manager" OR "staff product marketing manager") ("remote" OR "remote-first") ("US" OR "United States")
```

---

## Growth Marketing Manager

### Greenhouse + Lever
```
(site:greenhouse.io OR site:lever.co) ("growth marketing manager" OR "senior growth marketing manager" OR "growth marketing lead") ("remote" OR "remote-first") ("US" OR "United States")
```

### Greenhouse + Lever (demand gen / performance focused)
```
(site:greenhouse.io OR site:lever.co) ("demand generation" OR "performance marketing" OR "growth marketing") ("manager" OR "lead" OR "director") ("B2B" OR "SaaS") ("remote")
```

### Workday
```
site:myworkdayjobs.com ("growth marketing" OR "demand generation") ("manager" OR "lead") ("remote")
```

### ICIMS
```
site:careers.icims.com ("growth marketing manager" OR "demand generation manager") ("remote")
```

### Ashby
```
site:jobs.ashbyhq.com ("growth marketing manager" OR "senior growth marketing manager" OR "growth marketing lead") ("remote" OR "remote-first") ("US" OR "United States")
```

---

## Product Manager

### Greenhouse + Lever
```
(site:greenhouse.io OR site:lever.co) ("product manager" OR "senior product manager" OR "staff product manager") -("marketing") ("remote" OR "remote-first") ("US" OR "United States")
```

### Greenhouse + Lever (platform / infra focused)
```
(site:greenhouse.io OR site:lever.co) ("product manager" OR "senior PM") ("platform" OR "infrastructure" OR "developer tools" OR "API") ("remote")
```

### Workday
```
site:myworkdayjobs.com ("product manager" OR "senior product manager") ("remote" OR "remote-first")
```

### ICIMS
```
site:careers.icims.com ("product manager" OR "senior product manager") ("remote")
```

### Ashby
```
site:jobs.ashbyhq.com ("product manager" OR "senior product manager" OR "staff product manager") ("remote" OR "remote-first") ("US" OR "United States")
```

---

## Software Engineer — Backend

### Greenhouse + Lever
```
(site:greenhouse.io OR site:lever.co) ("software engineer" OR "backend engineer" OR "software developer") ("Python" OR "Go" OR "Java" OR "Node") ("senior" OR "staff") ("remote" OR "remote-first") ("US" OR "United States")
```

### Workday
```
site:myworkdayjobs.com ("software engineer" OR "backend engineer") ("senior" OR "staff") ("remote")
```

### ICIMS
```
site:careers.icims.com ("software engineer" OR "backend developer") ("senior") ("remote")
```

### Ashby
```
site:jobs.ashbyhq.com ("software engineer" OR "backend engineer") ("Python" OR "Go" OR "Java" OR "Node") ("senior" OR "staff") ("remote" OR "remote-first") ("US" OR "United States")
```

---

## Software Engineer — Frontend

### Greenhouse + Lever
```
(site:greenhouse.io OR site:lever.co) ("frontend engineer" OR "front-end engineer" OR "UI engineer") ("React" OR "TypeScript" OR "Next.js") ("senior" OR "staff") ("remote" OR "remote-first") ("US" OR "United States")
```

### Workday
```
site:myworkdayjobs.com ("frontend engineer" OR "front-end engineer") ("senior" OR "staff") ("remote")
```

### ICIMS
```
site:careers.icims.com ("frontend engineer" OR "front-end developer") ("senior") ("remote")
```

### Ashby
```
site:jobs.ashbyhq.com ("frontend engineer" OR "front-end engineer" OR "UI engineer") ("React" OR "TypeScript" OR "Next.js") ("senior" OR "staff") ("remote" OR "remote-first") ("US" OR "United States")
```

---

## UX / Product Designer

### Greenhouse + Lever
```
(site:greenhouse.io OR site:lever.co) ("UX designer" OR "product designer" OR "senior UX designer" OR "senior product designer") ("Figma") ("remote" OR "remote-first") ("US" OR "United States")
```

### Greenhouse + Lever (design systems focused)
```
(site:greenhouse.io OR site:lever.co) ("design systems" OR "UX lead" OR "staff designer") ("Figma" OR "design system") ("remote")
```

### Workday
```
site:myworkdayjobs.com ("product designer" OR "UX designer") ("senior" OR "lead") ("remote")
```

### ICIMS
```
site:careers.icims.com ("product designer" OR "UX designer") ("senior") ("remote")
```

### Ashby
```
site:jobs.ashbyhq.com ("UX designer" OR "product designer" OR "senior product designer") ("Figma") ("remote" OR "remote-first") ("US" OR "United States")
```

---

## Data Analyst / Data Scientist

### Greenhouse + Lever (analyst)
```
(site:greenhouse.io OR site:lever.co) ("data analyst" OR "senior data analyst" OR "analytics engineer") ("SQL" OR "Python" OR "dbt") ("remote" OR "remote-first") ("US" OR "United States")
```

### Greenhouse + Lever (data scientist)
```
(site:greenhouse.io OR site:lever.co) ("data scientist" OR "senior data scientist" OR "ML engineer") ("Python" OR "machine learning" OR "statistical modeling") ("remote" OR "remote-first") ("US" OR "United States")
```

### Workday
```
site:myworkdayjobs.com ("data analyst" OR "data scientist" OR "analytics engineer") ("senior") ("remote")
```

### ICIMS
```
site:careers.icims.com ("data analyst" OR "data scientist") ("senior") ("remote")
```

### Ashby
```
site:jobs.ashbyhq.com ("data analyst" OR "data scientist" OR "analytics engineer") ("SQL" OR "Python" OR "dbt") ("senior") ("remote" OR "remote-first") ("US" OR "United States")
```

---

## Customization Tips

**To target a specific city instead of remote:**
Replace `("remote" OR "remote-first")` with `("New York" OR "NYC")` or your city.

**To target a specific industry:**
Add `("fintech" OR "financial services")` or `("healthcare" OR "health tech")` to your query.

**To broaden or narrow seniority:**
- Add `"principal"` or `"director"` to go more senior
- Add `"associate"` or `"junior"` to go more junior
- Remove seniority terms entirely to cast the widest net

**To exclude terms:**
Use minus operator: `-(term)` — e.g., `-("manager" OR "director")` to exclude management roles, `-("crypto" OR "blockchain")` to skip those verticals.

**Testing a query before adding it:**
Paste the query string into Google (not Tavily) and inspect the results manually. If you're getting job postings, the query works. If you're getting blog posts or search result pages, tighten the query.
