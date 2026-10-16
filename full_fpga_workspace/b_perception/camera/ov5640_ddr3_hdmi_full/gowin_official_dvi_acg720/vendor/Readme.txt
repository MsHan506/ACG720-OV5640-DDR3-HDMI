________________________________________________________________________
	  Example DVI TX Design Read Me
-------------------------------------------------------------------------
Object device:GW2A-18C-PBGA484
---------------------------------------------------------------------------
File List:
---------------------------------------------------------------------------
.
|-- doc
|   `-- Readme.txt                              -->  Read Me file (this file)
|-- tb 
|   `-- tb.v                                    -->  TestBench for example design
|   `-- prim_sim.v                              -->  Gowin Simulation lib
|   |-- driver                                  -->  BMP picture driver
|   |-- monitor                                 -->  BMP picture monitor
|   |-- dvi_rx                                  -->  DVI to RGB for Simulation
|   |-- pic                                     -->  BMP picture for test
|-- project
|   `-- dk_video.gprj          	                -->  Gowin Project File for Example Design
|   `-- dk_video.gprj.user                      -->  Gowin Project File for Example Design
|   |-- impl
|   |   `-- project_process_config.json
|   |   |-- temp                                   
|   |-- src                          
|       `-- video_top.v                         -->  File for Gowin Project
|       `-- dk_video.cst                        -->  File for Gowin Project
|       `-- dk_video.sdc                        -->  File for Gowin Project 
|       `-- testpattern.v                       -->  File for Gowin Project 
|       |-- dvi_tx  
|       |-- temp        
|       |   `-- dvi_tx.v                        -->  File for Gowin Project(Encrypted)
|       |   `-- dvi_tx.vo                       -->  File for Simulation
|       |   `-- dvi_tx.ipc                      -->  File for Gowin Project
|       |   `-- dvi_tx_tmp.ipc                  -->  File for Gowin Project
|       |-- gowin_rpll          
|           `-- TMDS_rPLL.v                     -->  File for Gowin Project(Encrypted)
|           `-- TMDS_rPLL_tmp.v                 -->  File for Gowin Project
|           `-- TMDS_rPLL.mod                   -->  File for Gowin Project
|           `-- TMDS_rPLL.ipc                   -->  File for Gowin Project
|-- simulation                                  -->  Simulation Environment
|   |-- modelsim_sim
|   |   `-- readme.txt                          -->  Read Me file for modelsim simulation
|   |   `-- tb.do                               -->  File for Simulation run command
|   |-- vcs_sim
|       `-- readme.txt                          -->  Read Me file for modelsim simulation
|       `-- makefile                            -->  File for Simulation run command

---------------------------------------------------------------------------------------------------------------
HOW TO OPEN A PROJECT IN Gowin:
---------------------------------------------------------------------------------------------------------------
1. Unzip the respective design files.
2. Launch Gowin and select "File -> Open -> Project"
3. In the Open Project dialog, enter the Project location -- "project",select the project"dk_video.gprj".
4. Click Finish. Now the project is successfully loaded. 

---------------------------------------------------------------------------------------------------------------
HOW TO RUN SYNTHESIZE, PLACE AND ROUTE, IP CORE GENERATION, AND TIMING ANALYSIS IN Gowin:
---------------------------------------------------------------------------------------------------------------

1. Click the Process tab in the process panel of the Gowin dashboard. 
   Double click on Synthsize. This will bring the design through synthesis.
2. Click the Process tab in the process panel of the Gowin dashboard. 
   Double click on Place & Route. This will bring the design through mapping, place and route.
3. Once Place & Route is done, user can double click on Timing Analysis Report to get 
   the timing analysis result.
4. Click on "Project -> Configuration -> Place & Route" to configurate the Post-Place File 
   and SDF File of the design.
----------------------------------------------------------------------------------------------------------------

HOW TO RUN SIMULATION
1. User can run functional simulation by software VCS. 
2. User can check waveform by software Verdi.
----------------------------------------------------------------------------------------------------------------

HOW TO  GENERATE IP CORE
1. Click the IP Core Generator tab in the Window panel of the Gowin V1.9.9Beta-6 or later dashboard.
   Double click on "DVI TX". This will generate the IP Core for the design.
--------------------------------------------------------------------------------------------------------------

