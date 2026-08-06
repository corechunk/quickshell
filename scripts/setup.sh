#!/bin/bash

# Get the exact directory where this script lives
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "🚀 Setting up Google Classroom Daemon..."

# 1. Create the virtual environment if it doesn't exist
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "→ Creating Python virtual environment..."
    python3 -m venv "$SCRIPT_DIR/venv"
else
    echo "✓ Virtual environment already exists."
fi

# 2. Install/Update the required packages
echo "→ Installing Python packages..."
"$SCRIPT_DIR/venv/bin/pip" install --quiet --upgrade \
    google-api-python-client \
    google-auth-oauthlib \
    google-auth-httplib2

echo ""
echo "✅ Python setup complete!"
# 3. Check for credentials.jsonthisisagy1@gmail.com
if [ ! -f "$SCRIPT_DIR/credentials.json" ]; then
    echo ""
    echo "⚠️  Missing credentials.json!"
    echo "Let's set it up. I will guide you through the Google Cloud Console."
    echo "--------------------------------------------------------"
    
    # Step 1
    echo ""
    echo "1) First, we will open the Google Cloud Console."
    echo "   -> If it asks, create a project named 'Google Classroom' and click Create."
    echo "   -> Then it will show that it was created, Click on 'Get started'"
    echo "   -> Give 'App name' and 'User support email' and click Next"
    echo "   -> Under 'Audience', select 'External' and click Next."
    echo "   -> Under 'Contact information', enter the email address and click Next"
    echo "   -> Under 'Finish', check mark the 'I agree...' and click Continue, then click Create"
    read -p "   Press Enter to open the page..." -r
    xdg-open "https://console.cloud.google.com/apis/credentials/consent?project=_" 2>/dev/null &

    # Step 2
    echo ""
    echo "2) In the browser window that just opened:"
    echo "   -> Wait for the 'OAuth configuration created!' confirmation at the bottom."
    read -p "   Press Enter here once you see the confirmation in the browser..." -r

    # Step 3
    echo ""
    echo "3) Now we need to create the Client ID:"
    echo "   -> You should see 'Metrics' and 'Project Checkup' on the page."
    echo "   -> Under Metrics, click 'Create OAuth client'."
    read -p "   Press Enter here once you are on the Create Client page..." -r

    # Step 4
    echo ""
    echo "4) Configure the Client:"
    echo "   -> Application type: Select 'Desktop app'."
    echo "   -> Name: You can leave it as 'Desktop client 1'."
    echo "   -> Click 'Create'."
    read -p "   Press Enter here once you've clicked Create..." -r

    # Step 5
    echo ""
    echo "5) Success! You should see your Client ID and Secret."
    echo "   -> Click the 'Download JSON' button."
    echo "   -> Save it to your ~/Downloads folder (do not rename it)."
    read -p "   Press Enter here once the file has downloaded..." -r

    # Automated File Move
    echo ""
    echo "🔍 Looking for the downloaded credentials in ~/Downloads/..."
    DOWNLOADED_FILE=$(find ~/Downloads -maxdepth 1 -name "client_secret_*.json" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    
    if [ -n "$DOWNLOADED_FILE" ]; then
        echo "✅ Found it! Moving and renaming to credentials.json..."
        mv "$DOWNLOADED_FILE" "$SCRIPT_DIR/credentials.json"
    else
        echo "⚠️  Could not automatically find the file in ~/Downloads/."
        echo "   Please manually move and rename the downloaded file to:"
        echo "  $SCRIPT_DIR/credentials.json"
        read -p "   Press Enter once you have done this..." -r
    fi

    # Double check they actually did it
    if [ ! -f "$SCRIPT_DIR/credentials.json" ]; then
        echo ""
        echo "❌ Still can't find credentials.json in $SCRIPT_DIR"
        echo "   Please move and rename the file, then run this script again."
        exit 1
    fi
    
    echo ""
    echo "✅ credentials.json successfully created!"
    echo "--------------------------------------------------------"
    
    # The Missing "Allow App" Warning
    echo ""
    echo "⚠️  IMPORTANT - FIRST RUN WARNING:"
    echo "When you start Quickshell, a browser will open asking you to log into Google."
    echo "Google will show a warning: 'This app isn't verified'."
    echo "This is normal for personal projects. To proceed:"
    echo "  1) Click 'Advanced' (or 'Learn more')"
    echo "  2) Click 'Go to Google Classroom (unsafe)'"
    echo "  3) Click 'Continue' or 'Allow'"
    echo ""
fi

echo "🎉 Everything is ready! Start Quickshell to begin."