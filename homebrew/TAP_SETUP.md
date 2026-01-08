# Setting Up the Homebrew Tap

To make `screenshot-organizer` installable via Homebrew, you need to create a separate tap repository.

## Step 1: Create the Tap Repository

Create a new GitHub repo named `homebrew-tap` under your account:
- Repository name: `homebrew-tap`
- This allows users to run `brew tap flavioespinoza/tap`

## Step 2: Add the Formula

Copy `screenshot-organizer.rb` to the tap repository:

```bash
# Clone your tap repo
git clone https://github.com/flavioespinoza/homebrew-tap.git
cd homebrew-tap

# Copy the formula
cp /path/to/screenshot-organizer/homebrew/screenshot-organizer.rb Formula/

# Commit and push
git add Formula/screenshot-organizer.rb
git commit -m "Add screenshot-organizer formula"
git push
```

## Step 3: Create a Release Tag

Before users can install, you need to create a release with a tarball:

```bash
cd /path/to/screenshot-organizer
git tag v1.0.0
git push origin v1.0.0
```

## Step 4: Update the SHA256

After creating the tag, download the tarball and compute its SHA256:

```bash
curl -L https://github.com/flavioespinoza/screenshot-organizer/archive/refs/tags/v1.0.0.tar.gz -o v1.0.0.tar.gz
shasum -a 256 v1.0.0.tar.gz
```

Update the `sha256` line in the formula with the computed hash.

## Step 5: Test the Installation

```bash
brew tap flavioespinoza/tap
brew install screenshot-organizer
screenshot-organizer status
```

## Directory Structure for Tap Repo

```
homebrew-tap/
└── Formula/
    └── screenshot-organizer.rb
```
