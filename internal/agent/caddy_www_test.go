//go:build linux

package agent

import "testing"

func TestAddAutomaticWWWRedirectDomains(t *testing.T) {
	site := &siteInfo{
		PrimaryDomain: "promujswoje.eu",
		Domains: []siteDomainInfo{
			{Domain: "promujswoje.eu", IsPrimary: true, RedirectToPrimary: false},
		},
	}

	addAutomaticWWWRedirectDomains(map[string]*siteInfo{"site-1": site})

	wwwDomain, ok := site.wwwRedirectDomainFor("promujswoje.eu")
	if !ok {
		t.Fatalf("expected automatic www redirect domain to be present: %#v", site.Domains)
	}
	if wwwDomain != "www.promujswoje.eu" {
		t.Fatalf("www redirect domain = %q, want %q", wwwDomain, "www.promujswoje.eu")
	}
	if len(site.Domains) != 2 {
		t.Fatalf("domain count = %d, want 2: %#v", len(site.Domains), site.Domains)
	}
	if !site.Domains[1].RedirectToPrimary || site.Domains[1].IsPrimary {
		t.Fatalf("www domain should be non-primary redirect: %#v", site.Domains[1])
	}
}

func TestAutomaticWWWRedirectDomainSkipsUnsupportedDomains(t *testing.T) {
	cases := []string{
		"www.promujswoje.eu",
		"localhost",
		"app.localhost",
		"example.local",
		"example.test",
		"",
	}
	for _, tc := range cases {
		if got := automaticWWWRedirectDomain(tc); got != "" {
			t.Fatalf("automaticWWWRedirectDomain(%q) = %q, want empty", tc, got)
		}
	}
}

func TestAutomaticWWWRedirectScheme(t *testing.T) {
	if got := automaticWWWRedirectScheme(false); got != "https" {
		t.Fatalf("production redirect scheme = %q, want https", got)
	}
	if got := automaticWWWRedirectScheme(true); got != "http" {
		t.Fatalf("dev redirect scheme = %q, want http", got)
	}
}
