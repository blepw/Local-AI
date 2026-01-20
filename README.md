# Local-AI

<img width="1172" height="973" alt="local_ai_bash" src="https://github.com/user-attachments/assets/2baad462-34a5-4ecd-9d7a-6b9ef0c288c7" />
<img width="896" height="964" alt="local_ai_bash2" src="https://github.com/user-attachments/assets/24554e6a-ebe2-4dae-806b-46e105c5a76e" />
<img width="1920" height="1000" alt="local_ai_html" src="https://github.com/user-attachments/assets/2320f1d5-dae8-4fbd-9cf4-4407e18122e3" />

# ===============================================================================================================
#  [ Goal ]
# - the goal of this script is to Automate the process of using ollama Ai models with an htmls,cs,js web server,  
# depending on a default model , or a model that suits the user according to hardware information 
#  [ How ]  
# - User runs start.sh or start.bat based on their operating system , that script downloads and checks for 
# prerequisites then gets system information and determines which model would be the best . The user then 
# chooses if they want to use the DEFAULT_MODEL , model by typing the name or available model . 
# The script then checks if that model is installed , if not it installs it using Ollama. 
# after that the user chooses what to use and creates a web server using server.py and everything else 
# needed for the functionality and user interface ( script.js , index.html , style.css ) 
# [More info]
# - Uses model_config.json to categorize the best model for hardware
# All the functionalities of the website are in script.js (button functions , logic)
# User can set their model of choose by name in DEFAULT_MODEL 
# UI_DIR is the 'location' of those files needed to run the webserver. (uses dirname instead of setting the path)
# ================================================================================================================


For windows : 
bat start.bat 

For linux : 
bash start.sh
