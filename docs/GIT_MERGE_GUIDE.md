# Git Worktree Merge Guide

## Current Situation
- You're in a Git worktree: `worktree-2025-12-16T20-40-49`
- You want to merge these changes back to `develop` branch
- Main repo location: `C:\Users\morit\Documents\PERSONAL\RoundnetBoard\`

## Step-by-Step Instructions

### Option 1: Commit in Worktree, Then Merge (Recommended)

```bash
# Step 1: Check current status in worktree
cd C:\Users\morit\Documents\PERSONAL\RoundnetBoard\roundnetboard.worktrees\worktree-2025-12-16T20-40-49
git status

# Step 2: Stage all changes
git add .

# Step 3: Commit the changes
git commit -m "feat: Add comprehensive tutorial system with Home, Board, and Annotation tutorials

- Implemented TutorialService for state management
- Added HomeTutorialOverlay with 5-step guided flow
- Added BoardTutorialOverlay with 11-step guided flow
- Added AnnotationTutorialOverlay (ready for integration)
- Integrated tutorials into HomeScreen and BoardScreen
- Added gesture icons and SafeArea protection
- Implemented listener pattern for tutorial triggers
- Added comprehensive debug logging
- Updated HelpScreen with tutorial launch buttons
- Auto-trigger home tutorial after onboarding"

# Step 4: Note the current branch name (probably something like worktree-2025-12-16T20-40-49)
git branch --show-current

# Step 5: Go back to main repo and switch to develop
cd C:\Users\morit\Documents\PERSONAL\RoundnetBoard\
git checkout develop

# Step 6: Pull latest develop (if working with remote)
git pull origin develop

# Step 7: Merge the worktree branch into develop
# Replace BRANCH_NAME with the name from Step 4
git merge worktree-2025-12-16T20-40-49

# Step 8: Push to remote (if applicable)
git push origin develop

# Step 9: Clean up the worktree (optional)
git worktree remove C:\Users\morit\Documents\PERSONAL\RoundnetBoard\roundnetboard.worktrees\worktree-2025-12-16T20-40-49
git branch -d worktree-2025-12-16T20-40-49
```

### Option 2: Copy Changes Without Git History

If you want to just copy the files without git history:

```bash
# Step 1: Go to main repo
cd C:\Users\morit\Documents\PERSONAL\RoundnetBoard\

# Step 2: Switch to develop
git checkout develop

# Step 3: Copy files from worktree to main repo
# (In Windows, use File Explorer or robocopy)
robocopy C:\Users\morit\Documents\PERSONAL\RoundnetBoard\roundnetboard.worktrees\worktree-2025-12-16T20-40-49 C:\Users\morit\Documents\PERSONAL\RoundnetBoard\ /E /XD .git /XF .git*

# Step 4: Stage and commit in develop
git add .
git commit -m "feat: Add comprehensive tutorial system"

# Step 5: Push (if applicable)
git push origin develop
```

### Option 3: Using VS Code / IDE

If using VS Code:

```
1. Open VS Code
2. File → Open Folder → Select main repo folder
   (C:\Users\morit\Documents\PERSONAL\RoundnetBoard\)
3. Click branch name in bottom-left corner
4. Select "develop" branch
5. Terminal → New Terminal
6. Run: git merge worktree-2025-12-16T20-40-49
7. Resolve any conflicts if needed
8. Source Control panel → Commit changes
9. Click "Sync" or "Push" to push to remote
```

## Files Changed (For Reference)

### New Files Created
```
lib/services/tutorial_service.dart
lib/widgets/home_tutorial_overlay.dart
lib/widgets/board_tutorial_overlay.dart
lib/widgets/annotation_tutorial_overlay.dart
CURRENT_STATUS.md
DEBUG_TEST_PLAN.md
QUICK_TEST_GUIDE.md
FIX_BUTTONS_NOT_SHOWING.md
TUTORIAL_INTERACTION_NOTES.md
TUTORIAL_IMPLEMENTATION.md
BOARD_TUTORIAL_INTEGRATION.md
NAVIGATION_FIX.md
FINAL_SUMMARY.md
```

### Modified Files
```
lib/main.dart
lib/screens/home_screen.dart
lib/screens/help_screen.dart
lib/screens/board_screen.dart
```

## Verification

After merge, verify everything works:

```bash
# In develop branch
cd C:\Users\morit\Documents\PERSONAL\RoundnetBoard\

# Check that files exist
ls lib/services/tutorial_service.dart
ls lib/widgets/home_tutorial_overlay.dart
ls lib/widgets/board_tutorial_overlay.dart

# Run the app to test
flutter run -d chrome

# If good, you're done!
```

## Troubleshooting

### If you get merge conflicts:

```bash
# See which files have conflicts
git status

# Edit conflicted files manually
# Look for <<<<<<< HEAD markers

# After resolving conflicts
git add .
git commit -m "Merge worktree-2025-12-16T20-40-49 into develop"
```

### If you want to abort the merge:

```bash
git merge --abort
```

### If worktree branch doesn't exist:

```bash
# List all branches
git branch -a

# List worktrees
git worktree list

# If needed, create a branch from worktree commits
cd C:\Users\morit\Documents\PERSONAL\RoundnetBoard\roundnetboard.worktrees\worktree-2025-12-16T20-40-49
git branch tutorial-implementation
git checkout tutorial-implementation

# Then merge that branch
cd C:\Users\morit\Documents\PERSONAL\RoundnetBoard\
git checkout develop
git merge tutorial-implementation
```

## Quick Command Summary

**Fastest way (assuming everything is committed):**

```bash
cd C:\Users\morit\Documents\PERSONAL\RoundnetBoard\
git checkout develop
git merge worktree-2025-12-16T20-40-49
git push origin develop
```

**Done!** Your develop branch now has all the tutorial implementation.
