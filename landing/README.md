# Landing page

The public site at **https://gatherinsight.baldanproject.my.id/** (English) and **/id.html** (Indonesian), plus the learning guide
**/platform.html** (English) and **/platform-id.html** (Indonesian), linked as "About the platform" from the main pages.

- Static HTML with scroll-driven scenes; screenshots in `img/` are the real application with demo data.
- The learning guide is generated from a content file and a small builder kept with the application; edit those and rebuild
  rather than editing `platform*.html` by hand (its `pl_*.webp` screenshots live in `img/` like the rest).
- Served by `nginx:1.27-alpine` on Cloud Run (`gatherinsight-landing`, scales to zero, max 3 instances) with
  long cache lifetimes for images, `no-cache` for pages and basic security headers (`nginx.conf`).
- Runs as its own service account with **no roles**: a static site needs nothing from the project.
- Deployed by [`.github/workflows/landing.yml`](../.github/workflows/landing.yml) on every push to `main` that
  touches this folder. The workflow builds the image, serves it in the runner and compares every page byte for byte
  with the committed file, pushes it to Artifact Registry, rolls it out, and then checks that both the Cloud Run URL
  and the custom domain serve exactly this commit.
- Manual fallback: `bash scripts/deploy-landing.sh` from the repository root.

Analytics: Google Analytics 4, loaded only on the live hostnames, with events for the contact actions and for how
far visitors read.
