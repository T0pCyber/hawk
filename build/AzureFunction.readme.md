# Setting up the release pipeline:

## Preliminary

Setting up a release pipeline, set the trigger to do continuous integration against the master branch only.
In Stage 1 set up a tasksequence:

## 1) PowerShell Task: Prerequisites

Have it execute `vsts-prerequisites.ps1`

## 2) PowerShell Task: Validate

Have it execute `vsts-prerequisites.ps1`

## 3) PowerShell Task: Build

Have it execute `vsts-build.ps1`.
The task requires two parameters:

 - `-LocalRepo`
 - `-WorkingDirectory $(System.DefaultWorkingDirectory)/_�name�`

## 4) Publish Test Results

Configure task to pick up nunit type of tests (rather than the default junit).
Configure task to execute, even if previous steps failed or the task sequence was cancelled.

## 5) PowerShell Task: Package Function

Have it execute `vsts-packageFunction.ps1`

## 6) Azure Function AppDeploy

Configure to publish to the correct function app.