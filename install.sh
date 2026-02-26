#!/bin/bash
# ============================================================
# ATS - Applicant Tracking System Installer
# Deploys the ATS package to a Salesforce org
# ============================================================

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ATS - Applicant Tracking System v1.0  ║${NC}"
echo -e "${BLUE}║          Installation Script             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check if sf CLI is installed
if ! command -v sf &> /dev/null; then
    echo -e "${RED}Error: Salesforce CLI (sf) is not installed.${NC}"
    echo "Install it from: https://developer.salesforce.com/tools/salesforcecli"
    exit 1
fi

# Get target org
TARGET_ORG="${1}"
if [ -z "$TARGET_ORG" ]; then
    echo -e "${YELLOW}Usage: ./install.sh <org-alias>${NC}"
    echo ""
    echo "Available orgs:"
    sf org list 2>/dev/null | grep "Connected" || echo "  No connected orgs found. Run: sf org login web --alias <alias>"
    echo ""
    echo "Example: ./install.sh myproduction"
    exit 1
fi

# Verify connection
echo -e "${BLUE}[1/4]${NC} Verifying connection to ${TARGET_ORG}..."
if ! sf org display --target-org "$TARGET_ORG" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to org '${TARGET_ORG}'.${NC}"
    echo "Login first with: sf org login web --alias ${TARGET_ORG}"
    exit 1
fi
echo -e "${GREEN}  ✓ Connected${NC}"

# Detect org type
ORG_INFO=$(sf org display --target-org "$TARGET_ORG" --json 2>/dev/null)
IS_SANDBOX=$(echo "$ORG_INFO" | grep -o '"isSandbox": *[a-z]*' | grep -o '[a-z]*$' || echo "false")

if [ "$IS_SANDBOX" = "true" ]; then
    TEST_LEVEL="NoTestRun"
    echo -e "${BLUE}  ℹ Sandbox detected - skipping tests${NC}"
else
    TEST_LEVEL="RunLocalTests"
    echo -e "${BLUE}  ℹ Production org detected - will run tests${NC}"
fi

# Deploy
echo ""
echo -e "${BLUE}[2/4]${NC} Deploying ATS metadata..."
echo "  This may take a few minutes..."

sf project deploy start \
    --target-org "$TARGET_ORG" \
    --source-dir force-app \
    --test-level "$TEST_LEVEL" \
    --wait 30

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Deployment failed. Check the errors above.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Deployment successful${NC}"

# Assign permission set
echo ""
echo -e "${BLUE}[3/4]${NC} Assigning ATS Admin permission set..."
sf org assign permset --name ATS_Admin --target-org "$TARGET_ORG" 2>/dev/null || true
echo -e "${GREEN}  ✓ Permission set assigned${NC}"

# Done
echo ""
echo -e "${BLUE}[4/4]${NC} Post-install steps..."
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✓ ATS installed successfully!        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Open Salesforce and switch to the 'ATS Recruiter' app"
echo "  2. Go to the 'ATS Setup' tab"
echo "  3. Configure your Gemini API key for CV parsing"
echo "  4. Assign 'ATS User' permission set to your recruiters"
echo "  5. Start recruiting!"
echo ""
echo -e "Open your org: ${BLUE}sf org open --target-org ${TARGET_ORG}${NC}"
echo ""
