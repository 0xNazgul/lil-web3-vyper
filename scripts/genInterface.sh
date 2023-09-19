# Generates .sol interfaces for all vy files in src
set -e # exit on error

# Clears both the abi and interface folders
if rm ./src/abi/* ; 
then
    # Do nothing
    echo Old abi removed
else
    touch ./src/abi/a
    rm ./src/abi/*
fi

if rm ./src/test/interfaces/* ; 
then
    # Do nothing
    echo Old interfaces removed
else
    touch ./src/test/interfaces/a
    rm ./src/test/interfaces/*
fi

echo -e "\nGenerating abi..."

for file in ./src/*.vy
do
    # Gets the base name of each file
    full_name=${file}
    base_name=$(basename -s .vy ${full_name})

    # Generates abi of vyper files
    vyper -f abi ./"${file}" -o ./src/abi/${base_name}.json && echo ${base_name} abi generated!
done    

echo -e "\nGenerating interfaces..."

for file_abi in ./src/abi/*.json
do
    # Gets the base name of each file
    full_name=${file_abi}
    base_name=$(basename -s .json ${full_name})

    # Generates interface from file abi
    cast interface ${file_abi} > ./src/test/interfaces/I${base_name}.sol && echo ${base_name} interface generated!
done

echo -e "\nCleaning interfaces..."

for file_interface in ./src/test/interfaces/*.sol
do
    full_Iname=${file_interface}
    base_Iname=$(basename -s .sol ${full_Iname})
    search=Interface

    # Changes interface name to its file name
    sed -i "s/${search//\//\\/}/${base_Iname//\//\\/}/g" $file_interface 

    # Adds the SPDX license to top of interface file
    sed -i '1s/^/\/\/ SPDX\-License\-Identifier\: NONE \n/' $file_interface && echo ${base_Iname} interface cleaned!
done 

# find/replace breaks formating of the interfaces
forge fmt  

echo -e "\nGeneration complete!"