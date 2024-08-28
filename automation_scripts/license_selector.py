import sys
import yaml

dependency_file = sys.argv[1]
multiple_license_string = "SELECT_FROM_LICENSES"
no_license_string = []
data_loaded = ""



with open(dependency_file, 'r') as stream:
    data_loaded = yaml.safe_load(stream)

dependencies=data_loaded.get("dependencies")



index_counter = 0
license_counter = 0
for dependency in dependencies:
    if dependency.get("selected_license") == multiple_license_string:
        if not dependency.get("licenses") == no_license_string:
            if len(dependency.get("licenses")) == 1:
              dependency["selected_license"] = dependency.get("licenses")[0]
              dependency["licenses"].insert(0, dependency.get("licenses")[0])
              data_loaded["dependencies"][index_counter] == dependency
            else:
                def myfunc(license):
                    dependency["selected_license"] = license
                for license in dependency.get("licenses"):
                    if license == "Apache-2.0":
                      myfunc(license)
                      break
                    elif license == "MIT":
                      myfunc(license)
                      break
                    elif license == "BSD-3-Clause":
                      myfunc(license)
                      break
                    elif license == "BSD-2-Clause":
                      myfunc(license)
                      break
                    elif license == "CDDL-1.0":
                      myfunc(license)
                      break
                    elif license == "CC0-1.0":
                      myfunc(license)
                      break
                    elif license == "CDDL-1.1":
                      myfunc(license)
                      break
                    elif license == "EPL-1.0":
                      myfunc(license)
                      break
                    elif license == "Android-Sdk":
                      myfunc(license = "MIT")
                      break
                data_loaded["dependencies"][index_counter] == dependency
        else:
            dependency["selected_license"] = "Apache-2.0"
            dependency["licenses"].insert(0, "Apache-2.0")
            data_loaded["dependencies"][index_counter] == dependency
    index_counter +=1

with open(dependency_file, "w") as file:
    yaml.safe_dump(data_loaded, file, default_flow_style=False)