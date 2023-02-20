# Marmoview
MarmoV6! is the current working version of Marmoview, which runs the stimulus / behavioral protocols from [Marmolab](https://marmolab.bcs.rochester.edu/people.html) at the University of Rochester. The Huk lab, in colaboration with Jake Yates is making edits on this to expand its capabilities while (hopefully) preserving its simplicity and usability.

Key idea is that there are three levels of abstraction which require different levels of coding 'hardness.' The modular design makes it easier to plug and play the same code on all rigs independant of hardware, but makes the code opaque for users.
  - Gui: Main functions embedded in a gui that should never need to change, calls whatever hardware for inputs/outputs are available (set in MarmoViewRigSettings)
  - Protocols: brains of an experiment, also somewhat meant to be somewhat agnostic to inputs and outputs although this is not always possible
  - Settings: this is where the variables are initialised but can also be changed on the fly in the gui. These are meant to be changed constantly and easily
 
In order to allow for any possible experiment that fits into the constraints of the gui, a lot of the workhorse functions are hidden in Protocol methods. We are building a PR_tutorial.m file that has more of the gritty detail. This is all you should need to edit in order to set up a new psychophysics experiment. Basically if you find yourself needed to edit the Marmov6.m file in order to get your experiment to work, we messed up!

# Setup
This codebase is not user friendly. If you are interested in working with it, contact [Jake Yates](yates@umd.edu) by email. In the future, he might write a wiki page on how to use it, but for now, email to set up a meeting. Before you do that though,
follow these steps to make sure it is installed on you machine (You can run it on your laptop if you jsut want to test it).

### Steps

0. Download and install Psychtoolbox for Matlab for your machine
1. Fork the repository. Clone that fork to you own your own machine
2. Open matlab, change to the MarmoV6 directory and add all paths

``` 
addpath(genpath(pwd))
```
3. Edit the `MarmoViewRigSettings.m` file and switch the RigName to 'laptop', or set up your own rig. Use the existing rigs as models for this.
4. Open the Marmoview GUI from the command window
```
MarmoV6
```
This will open the Marmoview GUI. Enter the subject name and hit enter. Then use the `SettingsFile` tab and hit `Browse` to load a protocol. Pick `Forage11_DriftingGratings` to get started.

Make sure this runs. Then contact Jake.

### Debugging tricks
If MarmoV5 crashes, close the screen with `sca` and close the GUI with `close all force`. This will get you back to the starting point.


### Aknowledgements
Marmoview has been developed by several people over the years and is based off the synchronization schema developed for [PLDAPS](https://www.frontiersin.org/articles/10.3389/fninf.2012.00001/full)
Jacob Yates, Sean Cloherty, Sam Nummela, Jude Mitchell
