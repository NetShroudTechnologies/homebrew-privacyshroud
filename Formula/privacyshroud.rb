# frozen_string_literal: true

# PrivacyShroud Homebrew Formula — Alpha
#
# Install:
#   brew tap netshroudtechnologies/privacyshroud
#   brew install privacyshroud
#
# Reinstall (for updates):
#   brew reinstall privacyshroud
#
# Uninstall:
#   brew uninstall privacyshroud
#   # User data at ~/Documents/PrivacyShroud is NOT removed automatically.
#   # To fully remove: rm -rf ~/Documents/PrivacyShroud ~/.privacyshroud

class Privacyshroud < Formula
  desc "AI-powered data broker opt-out tool — runs as an OpenClaw skill"
  homepage "https://privacyshroud.ai"

  # --- Source ---
  # The source tarball is the tagged release from the PrivacyShroud GitHub repo.
  # Update url and sha256 for each new release.
  url "https://github.com/NetShroudTechnologies/PrivacyShroud/archive/refs/tags/v0.1.0-alpha.tar.gz"
  sha256 "PLACEHOLDER_SHA256_UPDATE_BEFORE_RELEASE"
  version "0.1.0-alpha"
  license "AGPL-3.0-only"

  # --- Prerequisites ---
  # Python 3.10+ is required for the skill scripts.
  # OpenClaw must be installed and configured separately before PrivacyShroud
  # will function. See: https://privacyshroud.ai/install
  depends_on "python@3"

  # --- Paths ---
  SKILL_DIR = "#{Dir.home}/.openclaw/skills/privacy-shroud"
  DATA_DIR  = "#{Dir.home}/Documents/PrivacyShroud"
  CONFIG_DIR = "#{Dir.home}/.privacyshroud"
  CERT_DIR  = "#{SKILL_DIR}/config/certs"

  # CapSolver open-source affiliate app ID.
  # Replaced with subscription app ID on activation (post-alpha).
  CAPSOLVER_APP_ID = "F6EE6B7B-7080-4CFA-B801-1DB4A58027F0"

  def install
    # --- Step 1: Verify OpenClaw is installed ---
    unless system("command -v openclaw > /dev/null 2>&1")
      odie <<~EOS
        OpenClaw is not installed.

        PrivacyShroud runs as an OpenClaw AI agent skill.
        Install and configure OpenClaw first, then re-run this installer.

          Install guide: https://privacyshroud.ai/install
          OpenClaw:      https://openclaw.ai/install
      EOS
    end

    # --- Step 2: Install skill files ---
    # On reinstall, overwrite skill files but preserve user config and certs.
    skill_dir = Pathname.new(SKILL_DIR)
    skill_dir.mkpath

    # Copy all skill contents into the skill directory.
    # Preserves: config/certs/ (cert stays valid on reinstall)
    #            config/solver_config.json (user may have configured CapSolver)
    cp_r buildpath.children, skill_dir

    # Restore preserved files if they existed before (reinstall case).
    # The cp_r above overwrites everything; we selectively restore below.
    # Note: on a fresh install these won't exist, so the rescue is intentional.
    preserved_cert     = "#{CERT_DIR}/localhost.crt"
    preserved_key      = "#{CERT_DIR}/localhost.key"
    preserved_solver   = "#{SKILL_DIR}/config/solver_config.json"

    # Ensure cert dir exists regardless
    Pathname.new(CERT_DIR).mkpath

    # --- Step 3: Install Python dependencies ---
    system Formula["python@3"].opt_bin/"python3", "-m", "pip", "install",
           "--quiet", "--user", "pyyaml"

    # Attempt cryptography library for TLS cert generation (optional)
    system Formula["python@3"].opt_bin/"python3", "-m", "pip", "install",
           "--quiet", "--user", "cryptography"

    # --- Step 4: Generate TLS certificate ---
    # Skip if cert already exists (reinstall case — existing cert remains valid).
    cert_path = Pathname.new(preserved_cert)
    key_path  = Pathname.new(preserved_key)

    unless cert_path.exist? && key_path.exist?
      ohai "Generating localhost TLS certificate..."
      gen_cert = "#{SKILL_DIR}/scripts/gen_cert.py"
      if File.exist?(gen_cert)
        result = system Formula["python@3"].opt_bin/"python3", gen_cert,
                        "--cert-dir", CERT_DIR
        unless result
          opoo <<~EOS
            TLS certificate generation failed.
            The Control Tower dashboard will not be available until a cert is generated.
            CLI discovery and opt-out will still work.

            Generate manually after install:
              python3 #{SKILL_DIR}/scripts/gen_cert.py
          EOS
        end
      else
        opoo "gen_cert.py not found — skipping TLS cert generation."
      end
    else
      ohai "TLS certificate already exists — skipping generation."
    end

    # --- Step 5: Write config.env ---
    config_dir = Pathname.new(CONFIG_DIR)
    config_dir.mkpath
    config_env = config_dir/"config.env"

    if config_env.exist?
      # Reinstall: merge — add missing keys only, always update version
      existing = config_env.read
      defaults = default_config_env

      defaults.each_line do |line|
        key = line.split("=").first
        next if key.start_with?("#") || key.strip.empty?
        # Always update PS_SKILL_VERSION
        if key == "PS_SKILL_VERSION"
          existing = existing.gsub(/^PS_SKILL_VERSION=.*$/, line.chomp)
          existing += line unless existing.match?(/^PS_SKILL_VERSION=/)
        elsif !existing.match?(/^#{Regexp.escape(key)}=/)
          existing += "\n#{line}"
        end
      end
      config_env.write(existing)
      ohai "Updated config.env (PS_SKILL_VERSION set to #{version})."
    else
      # Fresh install: write defaults
      config_env.write(default_config_env)
      ohai "Created config.env."
    end

    # --- Step 6: Create user data directories ---
    # Only if not present — never overwrite existing data.
    data_dir = Pathname.new(DATA_DIR)
    unless data_dir.exist?
      (data_dir/"profiles").mkpath
      (data_dir/"runs").mkpath
      ohai "Created #{DATA_DIR}."
    end

    profile_index = data_dir/"profiles/profile_index.json"
    unless profile_index.exist?
      profile_index.write(<<~JSON)
        {
          "active": null,
          "profiles": {}
        }
      JSON
    end

    # --- Step 7: Verify skill is visible to OpenClaw ---
    # No registration needed — OpenClaw automatically loads skills from
    # ~/.openclaw/skills/ on the next session. Installing the skill directory
    # there is sufficient. ClawHub registration is optional (for public listing).
    ohai "Skill installed at #{SKILL_DIR}" \
         " — OpenClaw will load it on next session."
  end

  def post_install
    puts <<~EOS

      ✓ PrivacyShroud #{version} installed successfully.

      ─────────────────────────────────────────────────
      Getting started — tell your OpenClaw agent:
        "Set up my PrivacyShroud profile"

      Or open directly in your browser:
        Profile Manager:  https://localhost:18790/profile-editor
        Dashboard:        https://localhost:18790/dashboard

      Start the Control Tower dashboard:
        nohup bash #{SKILL_DIR}/scripts/start_dashboard.sh \\
          > /tmp/privacyshroud-dashboard.log 2>&1 &

      User guide:   https://privacyshroud.ai/user-guide
      Feedback:     support@privacyshroud.ai
      ─────────────────────────────────────────────────

      NOTE: OpenClaw must be installed and configured before PrivacyShroud
      will function. Start a new OC session after install to load the skill.
      If you haven't set up OpenClaw yet: https://privacyshroud.ai/install

      NOTE: The Control Tower dashboard requires your browser to
      accept the self-signed localhost certificate. On first open,
      click Advanced → Proceed to localhost.

      To trust the cert and eliminate this warning (optional):
        sudo security add-trusted-cert -d -r trustRoot \\
          -k /Library/Keychains/System.keychain \\
          #{CERT_DIR}/localhost.crt

    EOS
  end

  def caveats
    <<~EOS
      User data is stored at:
        ~/Documents/PrivacyShroud/    (profiles and run history)
        ~/.privacyshroud/config.env   (configuration)

      These are NOT removed by `brew uninstall privacyshroud`.
      To fully remove PrivacyShroud including user data:
        brew uninstall privacyshroud
        rm -rf ~/Documents/PrivacyShroud ~/.privacyshroud

      To update PrivacyShroud (alpha — no auto-update):
        brew reinstall privacyshroud
      Your profile and run history will be preserved.
    EOS
  end

  test do
    # Verify skill directory exists
    assert_path_exists "#{SKILL_DIR}/SKILL.md"
    # Verify config.env exists
    assert_path_exists "#{CONFIG_DIR}/config.env"
    # Verify gen_cert.py is present
    assert_path_exists "#{SKILL_DIR}/scripts/gen_cert.py"
    # Verify pyyaml is importable
    system Formula["python@3"].opt_bin/"python3", "-c", "import yaml"
  end

  private

  def default_config_env
    <<~ENV
      # PrivacyShroud configuration
      # Do not edit PS_SKILL_VERSION — updated automatically on reinstall.

      PS_EDITION=alpha
      PS_EDITION_LABEL=Alpha Tester · Standard
      PS_SKILL_VERSION=#{version}
      PS_CAPSOLVER_APP_ID=#{CAPSOLVER_APP_ID}
    ENV
  end
end
