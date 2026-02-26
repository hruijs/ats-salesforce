# ATS - Applicant Tracking System for Salesforce

A complete Applicant Tracking System built as a single Lightning Web Component for Salesforce. Manage candidates, jobs, interviews, and your recruitment pipeline from one unified dashboard.

## Features

- **CV Parsing** - Upload PDF resumes and automatically extract candidate data using Google Gemini AI
- **Candidate Management** - Search, filter, and manage all candidates with the "Candidate" record type on Contact
- **Job Management** - Create and manage job openings with status tracking
- **Interview Scheduling** - Schedule interviews with up to 2 interviewers per session, directly editable from the dashboard
- **Pipeline Board** - Drag-and-drop Kanban board for managing application stages (New, Screening, Interview, Evaluation, Offer, Hired)
- **Dashboard** - Real-time overview of open jobs, active candidates, upcoming interviews, and pipeline statistics
- **Setup Wizard** - Built-in configuration page for API settings and user management

## Quick Install

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) installed
- A Salesforce org (Production or Sandbox) authenticated with `sf org login web`

### Option 1: One-command install (recommended)

```bash
# 1. Clone the repository
git clone https://github.com/hruijs/ats-salesforce.git
cd ats-salesforce

# 2. Run the installer
./install.sh <your-org-alias>
```

The install script automatically:
- Verifies your org connection
- Detects sandbox vs production (adjusts test level accordingly)
- Deploys all metadata
- Assigns the ATS Admin permission set

### Option 2: Manual deploy

```bash
# 1. Clone the repository
git clone https://github.com/hruijs/ats-salesforce.git
cd ats-salesforce

# 2. Deploy to your target org (sandbox)
sf project deploy start --target-org <your-org-alias> --source-dir force-app --test-level NoTestRun --wait 30

# 2. Deploy to your target org (production - runs tests)
sf project deploy start --target-org <your-org-alias> --source-dir force-app --test-level RunLocalTests --wait 30

# 3. Assign permission set to your admin user
sf org assign permset --name ATS_Admin --target-org <your-org-alias>
```

### Post-Install Setup

1. Open Salesforce and switch to the **ATS Recruiter** app (via App Launcher)
2. Go to the **ATS Setup** tab
3. Configure your **Google Gemini API key** for CV parsing ([Get your key here](https://aistudio.google.com/apikey))
4. Assign the **ATS User** permission set to recruiters and hiring managers
5. Go to the **ATS Hub** tab and start recruiting!

## What's Included

### Custom Objects
| Object | Description |
|--------|-------------|
| `Job__c` | Job openings with title, department, salary range, status |
| `Application__c` | Links candidates to jobs with stage tracking |
| `Interview__c` | Interview scheduling with 2 interviewer slots |
| `Scorecard__c` | Interview evaluation with ratings |
| `Offer__c` | Job offers with salary, benefits, status |
| `Hiring_Team_Member__c` | Team members assigned to jobs |
| `CV_Parser_Settings__mdt` | Custom metadata for Gemini API configuration |

### Contact Extensions
- **Candidate record type** on Contact (auto-assigned to all ATS candidates)
- Custom fields: Skills, Languages, Education, Work Experience, CV Parsed, LinkedIn URL, etc.

### Lightning Components
| Component | Description |
|-----------|-------------|
| `atsHub` | Main ATS dashboard (all tabs in one component) |
| `atsSetup` | Setup wizard for post-install configuration |
| `atsJobDashboard` | Job statistics and pipeline overview |
| `candidatePipeline` | Drag-and-drop Kanban pipeline board |
| `cvPdfViewer` | CV viewer with AI parsing |

### Apex Controllers
| Class | Description |
|-------|-------------|
| `ATSHubController` | Central controller for all ATS operations |
| `ApplicationController` | Pipeline and job dashboard data |
| `ATSSetupController` | Setup page API settings and user management |
| `GeminiService` | Google Gemini AI integration for CV parsing |
| `CVFileController` | CV file management |
| `CVParsingQueueable` | Async CV parsing |

### Permission Sets
| Permission Set | Description |
|---------------|-------------|
| `ATS_User` | Standard access for recruiters (CRUD on all ATS objects) |
| `ATS_Admin` | Full admin access + Modify All + setup capabilities |

### Lightning App
- **ATS Recruiter** - Lightning app with ATS Hub and ATS Setup tabs

## Remote Site Settings

The package includes a Remote Site Setting for the Google Gemini API:
- **GeminiAPI**: `https://generativelanguage.googleapis.com`

## Version History

| Version | Description |
|---------|-------------|
| 1.0.0 | Initial release - CV parsing, pipeline management, interview scheduling, setup wizard |

## License

MIT
