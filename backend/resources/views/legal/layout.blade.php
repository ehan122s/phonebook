<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title') - Phonebook</title>
    <meta name="description" content="@yield('meta_description', 'Kebijakan dan Ketentuan Layanan Aplikasi Phonebook - CDK Wilayah V Garut')">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #245C3A;
            --primary-hover: #1b472c;
            --primary-light: #eaf3ec;
            --primary-glow: rgba(36, 92, 58, 0.15);
            --accent: #2e7d4e;
            --text-main: #1e293b;
            --text-muted: #64748b;
            --bg-page: #f8faf8;
            --bg-card: #ffffff;
            --border: #e2e8f0;
            --border-highlight: #cbd5e1;
            --code-bg: #f1f5f9;
            --shadow-sm: 0 1px 3px rgba(0,0,0,0.05);
            --shadow-md: 0 4px 16px -2px rgba(36, 92, 58, 0.08), 0 2px 6px -1px rgba(0,0,0,0.04);
            --shadow-lg: 0 12px 32px -4px rgba(36, 92, 58, 0.12);
            --radius-sm: 8px;
            --radius-md: 12px;
            --radius-lg: 18px;
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --primary: #348a56;
                --primary-hover: #40a568;
                --primary-light: #162e20;
                --primary-glow: rgba(52, 138, 86, 0.25);
                --accent: #4ade80;
                --text-main: #f1f5f9;
                --text-muted: #94a3b8;
                --bg-page: #0d1410;
                --bg-card: #131c16;
                --border: #1e2e24;
                --border-highlight: #283e30;
                --code-bg: #1a2820;
                --shadow-sm: 0 1px 3px rgba(0,0,0,0.3);
                --shadow-md: 0 4px 16px -2px rgba(0,0,0,0.4);
                --shadow-lg: 0 12px 32px -4px rgba(0,0,0,0.5);
            }
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background-color: var(--bg-page);
            color: var(--text-main);
            line-height: 1.7;
            -webkit-font-smoothing: antialiased;
            text-rendering: optimizeLegibility;
        }

        /* Top Banner & Header */
        header {
            background: var(--bg-card);
            border-bottom: 1px solid var(--border);
            position: sticky;
            top: 0;
            z-index: 50;
            backdrop-filter: blur(12px);
        }

        .nav-container {
            max-width: 1040px;
            margin: 0 auto;
            padding: 16px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
        }

        .brand-link {
            display: flex;
            align-items: center;
            gap: 12px;
            text-decoration: none;
            color: var(--text-main);
            font-weight: 700;
            font-size: 1.15rem;
            letter-spacing: -0.02em;
        }

        .brand-icon {
            width: 38px;
            height: 38px;
            background: linear-gradient(135deg, #245C3A 0%, #348a56 100%);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #ffffff;
            box-shadow: 0 4px 10px rgba(36, 92, 58, 0.3);
            flex-shrink: 0;
        }

        .brand-text {
            display: flex;
            flex-direction: column;
        }

        .brand-title {
            font-size: 1.05rem;
            font-weight: 800;
            line-height: 1.2;
            color: var(--text-main);
        }

        .brand-subtitle {
            font-size: 0.72rem;
            color: var(--text-muted);
            font-weight: 500;
            letter-spacing: 0.02em;
        }

        .nav-links {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .nav-tab {
            padding: 8px 16px;
            border-radius: var(--radius-sm);
            text-decoration: none;
            font-size: 0.88rem;
            font-weight: 600;
            color: var(--text-muted);
            transition: all 0.2s ease;
        }

        .nav-tab:hover {
            color: var(--primary);
            background: var(--primary-light);
        }

        .nav-tab.active {
            color: #ffffff;
            background: var(--primary);
            box-shadow: 0 2px 8px var(--primary-glow);
        }

        /* Hero Header */
        .hero-section {
            background: linear-gradient(180deg, var(--bg-card) 0%, var(--bg-page) 100%);
            border-bottom: 1px solid var(--border);
            padding: 48px 24px 40px;
            text-align: center;
        }

        .hero-inner {
            max-width: 780px;
            margin: 0 auto;
        }

        .badge-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 14px;
            border-radius: 999px;
            font-size: 0.78rem;
            font-weight: 700;
            letter-spacing: 0.04em;
            text-transform: uppercase;
            background: var(--primary-light);
            color: var(--primary);
            border: 1px solid var(--border);
            margin-bottom: 16px;
        }

        .badge-dot {
            width: 8px;
            height: 8px;
            background: #22c55e;
            border-radius: 50%;
            box-shadow: 0 0 0 2px rgba(34, 197, 94, 0.2);
        }

        .hero-title {
            font-size: 2.3rem;
            font-weight: 800;
            letter-spacing: -0.03em;
            color: var(--text-main);
            line-height: 1.25;
            margin-bottom: 12px;
        }

        .hero-desc {
            font-size: 1.05rem;
            color: var(--text-muted);
            line-height: 1.6;
            margin-bottom: 20px;
        }

        .meta-chips {
            display: flex;
            align-items: center;
            justify-content: center;
            flex-wrap: wrap;
            gap: 16px;
            font-size: 0.82rem;
            color: var(--text-muted);
        }

        .meta-chip {
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        /* Main Content Container */
        .main-wrapper {
            max-width: 960px;
            margin: -20px auto 60px;
            padding: 0 24px;
        }

        .content-card {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius-lg);
            padding: 44px 48px;
            box-shadow: var(--shadow-md);
        }

        @media (max-width: 680px) {
            .content-card {
                padding: 24px 20px;
            }
            .hero-title {
                font-size: 1.8rem;
            }
            .nav-container {
                flex-direction: column;
                align-items: flex-start;
            }
            .nav-links {
                width: 100%;
                justify-content: flex-start;
                overflow-x: auto;
            }
        }

        /* Typography & Legal Content Styles */
        .legal-content h2 {
            font-size: 1.35rem;
            font-weight: 700;
            letter-spacing: -0.02em;
            color: var(--text-main);
            margin-top: 36px;
            margin-bottom: 12px;
            padding-bottom: 8px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .legal-content h2:first-of-type {
            margin-top: 10px;
        }

        .section-number {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 28px;
            height: 28px;
            border-radius: 8px;
            background: var(--primary-light);
            color: var(--primary);
            font-size: 0.85rem;
            font-weight: 800;
            flex-shrink: 0;
        }

        .legal-content h3 {
            font-size: 1.05rem;
            font-weight: 700;
            color: var(--text-main);
            margin-top: 22px;
            margin-bottom: 8px;
        }

        .legal-content p {
            font-size: 0.95rem;
            color: var(--text-main);
            margin-bottom: 14px;
            line-height: 1.75;
        }

        .legal-content ul, .legal-content ol {
            margin: 12px 0 18px 24px;
            font-size: 0.94rem;
            line-height: 1.7;
        }

        .legal-content li {
            margin-bottom: 8px;
            color: var(--text-main);
        }

        .legal-content strong {
            color: var(--text-main);
            font-weight: 700;
        }

        /* Callout / Notice Box */
        .callout-box {
            background: var(--primary-light);
            border-left: 4px solid var(--primary);
            border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
            padding: 16px 20px;
            margin: 20px 0;
            font-size: 0.92rem;
            color: var(--text-main);
        }

        .callout-box.info {
            background: #eff6ff;
            border-left-color: #3b82f6;
            color: #1e3a8a;
        }

        @media (prefers-color-scheme: dark) {
            .callout-box.info {
                background: #172554;
                border-left-color: #60a5fa;
                color: #dbeafe;
            }
        }

        .callout-title {
            font-weight: 700;
            margin-bottom: 4px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        /* Code & Pre */
        code {
            font-family: 'JetBrains Mono', monospace;
            background: var(--code-bg);
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.86em;
            color: var(--primary);
        }

        /* Table */
        .table-responsive {
            overflow-x: auto;
            margin: 20px 0;
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9rem;
            text-align: left;
        }

        th {
            background: var(--bg-page);
            font-weight: 700;
            padding: 12px 16px;
            border-bottom: 1px solid var(--border);
            color: var(--text-main);
        }

        td {
            padding: 12px 16px;
            border-bottom: 1px solid var(--border);
            color: var(--text-main);
        }

        tr:last-child td {
            border-bottom: none;
        }

        /* Quick Navigation / Table of Contents */
        .toc-card {
            background: var(--bg-page);
            border: 1px solid var(--border);
            border-radius: var(--radius-md);
            padding: 20px 24px;
            margin-bottom: 32px;
        }

        .toc-title {
            font-size: 0.9rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 12px;
        }

        .toc-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 8px 16px;
            list-style: none;
            margin: 0;
            padding: 0;
        }

        .toc-link {
            color: var(--primary);
            text-decoration: none;
            font-size: 0.88rem;
            font-weight: 500;
            transition: color 0.15s ease;
        }

        .toc-link:hover {
            text-decoration: underline;
            color: var(--primary-hover);
        }

        /* Footer */
        footer {
            border-top: 1px solid var(--border);
            background: var(--bg-card);
            padding: 40px 24px;
            font-size: 0.88rem;
            color: var(--text-muted);
            margin-top: 40px;
        }

        .footer-inner {
            max-width: 960px;
            margin: 0 auto;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 16px;
        }

        .footer-links {
            display: flex;
            gap: 20px;
        }

        .footer-link {
            color: var(--text-muted);
            text-decoration: none;
            transition: color 0.15s ease;
        }

        .footer-link:hover {
            color: var(--primary);
        }
    </style>
</head>
<body>

    <!-- Header Navigation -->
    <header>
        <div class="nav-container">
            <a href="{{ url('/') }}" class="brand-link">
                <div class="brand-icon">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                        <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                        <circle cx="12" cy="8" r="2"/>
                        <path d="M10 13a2 2 0 0 1 4 0"/>
                    </svg>
                </div>
                <div class="brand-text">
                    <span class="brand-title">Phonebook CDK V</span>
                    <span class="brand-subtitle">Dinas Kehutanan Provinsi Jawa Barat</span>
                </div>
            </a>
            <nav class="nav-links">
                <a href="{{ url('/terms') }}" class="nav-tab {{ request()->is('terms*') ? 'active' : '' }}">
                    Ketentuan Layanan
                </a>
                <a href="{{ url('/privacy') }}" class="nav-tab {{ request()->is('privacy*') ? 'active' : '' }}">
                    Kebijakan Privasi
                </a>
            </nav>
        </div>
    </header>

    <!-- Hero Header -->
    <section class="hero-section">
        <div class="hero-inner">
            <div class="badge-pill">
                <span class="badge-dot"></span>
                @yield('badge_text', 'Dokumen Kepatuhan & Legal Resmi')
            </div>
            <h1 class="hero-title">@yield('page_heading')</h1>
            <p class="hero-desc">@yield('page_subheading')</p>
            <div class="meta-chips">
                <span class="meta-chip">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10"/>
                        <polyline points="12 6 12 12 16 14"/>
                    </svg>
                    Terakhir Diperbarui: <strong>18 November 2026</strong>
                </span>
                <span class="meta-chip">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                    </svg>
                    Versi Dokumen: <strong>2.4.0 (Discord Bot Ready)</strong>
                </span>
                <span class="meta-chip">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="2" y="3" width="20" height="14" rx="2" ry="2"/>
                        <line x1="8" y1="21" x2="16" y2="21"/>
                        <line x1="12" y1="17" x2="12" y2="21"/>
                    </svg>
                    Platform: <strong>Mobile App & Discord Bot</strong>
                </span>
            </div>
        </div>
    </section>

    <!-- Main Content -->
    <main class="main-wrapper">
        <article class="content-card">
            @yield('content')
        </article>
    </main>

    <!-- Footer -->
    <footer>
        <div class="footer-inner">
            <div>
                &copy; {{ date('Y') }} <strong>Phonebook CDK V Garut</strong> &bull; Cabang Dinas Kehutanan Wilayah V Jawa Barat.
            </div>
            <div class="footer-links">
                <a href="{{ url('/terms') }}" class="footer-link">Ketentuan Layanan</a>
                <a href="{{ url('/privacy') }}" class="footer-link">Kebijakan Privasi</a>
                <a href="{{ url('/') }}" class="footer-link">Status Sistem</a>
            </div>
        </div>
    </footer>

</body>
</html>
