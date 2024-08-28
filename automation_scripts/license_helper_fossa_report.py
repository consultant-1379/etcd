import sys
import json

report_file = sys.argv[1]
no_license_string = []
data_loaded = ""



with open(report_file, 'r') as stream:
    data_loaded = json.load(stream)
  
    def append_license(dependencies):
      for dependency in dependencies:
        Licenses = dependency['Licenses']
        if not Licenses == no_license_string:    
         for License in Licenses:
            if License['Name'] == "Android-Sdk":
              Licenses.append({"Name":"MIT","Attribution": "Copyright (c) 2009 codehaus\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE."})
              break

    DirectDependencies = data_loaded['DirectDependencies']
    append_license(DirectDependencies)

    DeepDependencies = data_loaded['DeepDependencies']
    append_license(DeepDependencies)

with open(report_file, "w") as file:
    json.dump(data_loaded, file)