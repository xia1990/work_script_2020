#!/bin/bash

root=`pwd`
OLD_XML="$root/.repo/manifests/38_manifest.xml"
NEW_XML="$root/.repo/manifests/39_manifest.xml"

if [ -d ".repo" ];then
	cd $root/.repo/manifests
		repo diffmanifests $OLD_XML $NEW_XML > change_list.txt
	cd -
fi
release_diff="change_list.txt"
gerrit_server="gerrit.mot.com"

html_header='
<!DOCTYPE html >
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>CHANGE SEARCH LOG</title>
    <style type="text/css">
        a {color:#0066FF;text-decoration:none}
        th {background-color:#008B00}
    </style>
    <link rel="stylesheet" href="https://cdn.staticfile.org/twitter-bootstrap/3.3.7/css/bootstrap.min.css">  
    <script src="https://cdn.staticfile.org/jquery/2.1.1/jquery.min.js"></script>
    <script src="https://cdn.staticfile.org/twitter-bootstrap/3.3.7/js/bootstrap.min.js"></script>
</head>
<body>
    <base target="_blank" >
    <h1 class="text-center">CHANGE BETWEEN 2020-01-02 TO 2020-02-24</h1>
    <table class="table table-striped table-bordered">
        <tr>
            <th>URL</th>
            <th>SUBJECT</th>
            <th>AUTHOR</th>
            <th>CR</th>
            <th>Description</th>
            <th>Components</th>
            <th>assign</th>
        </tr>
'

html_tail='
    </table>
</body>
</html>
'

function get_commit_msg(){
echo $html_header > change_list.html

changed_from_array=($(grep -n 'changed from' $release_diff  | awk -F ':' '{print $1}')) # 和下面的数组一一对应
project_array=($(grep 'changed from' $release_diff  | awk '{print $1}')) #和上面的数组一一对应

changed_from_array_len=${#changed_from_array[@]}
total_line=`wc -l $release_diff | awk '{print $1}'`
for index in `seq 0 $((changed_from_array_len - 1))`
do
    project_path="${project_array[index]}"
    project_name=`repo list -n $project_path`

    #echo $project_path  :  $project_name
    ############表头 共3 列,如果要增加列html_header 里面也要增加##########
    echo "<tr><td colspan="6" style='text-align:left;font-weight:bold'>$project_path : $project_name </td></tr>" >> change_list.html
    #################################

    if [ $index == $((changed_from_array_len - 1)) ] #最后一行
    then
        #echo $index #放 change from 和 project 行号数组的 下标
        #echo $((${changed_from_array[$index]} + 1 )) $(($total_line - 1)) #commit_id 所在行
        commit_array=($(sed -n "$((${changed_from_array[index]} + 1 )),$(($total_line - 1))"p $release_diff |awk '{print $2}'))
        for commit_id in "${commit_array[@]}"
        do
            #echo $commit_id
            ssh -p 29418 $gerrit_server gerrit query commit:$commit_id --format JSON > temp.json
            temp_json_line=`wc -l temp.json| awk '{print $1}'`
            if [ "$temp_json_line" -eq 2 ]
            then
                url=`sed -n "1p" temp.json | jq .url | awk -F '"' '{print $2}'`
                subject=`sed -n "1p" temp.json | jq .subject | awk -F '"' '{print $2}'`
                author=`sed -n "1p" temp.json | jq .owner.name | awk -F '"' '{print $2}'`
				email=`sed -n "1p" temp.json | jq .owner.email | awk -F '"' '{print $2}'`
				cr=`sed -n "1p" temp.json | jq .subject | grep -aoe "IK[A-Z]*-[0-9]*"`
                assign=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.assignee.displayName`
				description=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.summary`
				components=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.components[0].name`
				cr_url="https://idart.mot.com/browse/$cr"
				echo "<tr><td><a href="$url">$url</a></td><td>$subject</td><td>$author</br>($eamil)</td><td><a href="$cr_url">$cr</a></td><td>$description</td><td>$components</td><td>$assign</td></tr>" >> change_list.html
            else
                echo "can not find commit in gerrit server" # commit gerrit上查不到只能从本地获取了
                if [ -d "$project_path" ]
                then
                    cd "${project_array[index]}"
                        subject=`git log $commit_id -n 1 --format="%s"`
                        author=`git log $commit_id -n 1 --format="%an"`
						email=`git log $commit_id -n 1 --format="%ae"`
						cr=`git log $commit_id -n 1 --format="%s" | grep -aoe "IK[A-Z]*-[0-9]*"`
						cr_url="https://idart.mot.com/browse/$cr"
						assign=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.assignee.displayName`
						description=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.summary`	
						components=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.components[0].name`
                    cd -
                fi
                echo "<tr><td>$commit_id</td><td>$subject</td><td>$author</br>($email)</td><td><a href="$cr_url">$cr</a></td><td>$description</td><td>$components</td><td>$assign</td></tr>" >> change_list.html
            fi
        done
    else
        #echo $index #放 change from 和 project 行号数组的 下标
        index_add_1=$((index + 1))
        #echo $((${changed_from_array[$index]} + 1 )) $((${changed_from_array[$index_add_1]} - 2)) #commit_id 所在行
        commit_array=($(sed -n "$((${changed_from_array[index]} + 1 )),$((${changed_from_array[$index_add_1]} - 2))"p $release_diff |awk '{print $2}'))
        for commit_id in "${commit_array[@]}"
        do
            #echo $commit_id
            ssh -p 29418 $gerrit_server gerrit query commit:$commit_id --format JSON > temp.json
            #cat temp.json
            temp_json_line=`wc -l temp.json| awk '{print $1}'`
            if [ "$temp_json_line" -eq 2 ]
            then
                url=`sed -n "1p" temp.json | jq .url | awk -F '"' '{print $2}'`
                subject=`sed -n "1p" temp.json | jq .subject | awk -F '"' '{print $2}'`
                author=`sed -n "1p" temp.json | jq .owner.name | awk -F '"' '{print $2}'`
				email=`sed -n "1p" temp.json | jq .owner.email | awk -F '"' '{print $2}'`
				cr=`sed -n "1p" temp.json | jq .subject | grep -aoe "IK[A-Z]*-[0-9]*"`
				assign=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.assignee.displayName`
				description=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.summary`
			    components=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.components[0].name`
				cr_url="https://idart.mot.com/browse/$cr"
				echo "<tr><td><a href="$url">$commit_id</a></td><td>$subject</td><td>$author</br>($email)</td><td><a href="$cr_url">$cr</a></td><td>$description</td><td>$components</td><td>$assign</td></tr>" >> change_list.html
            else
                echo "can not find commit in gerrit server" # commit gerrit上查不到只能从本地获取了
                if [ -d "$project_path" ]
                then
                    cd "${project_array[index]}"
                        subject=`git log $commit_id -n 1 --format="%s"`
                        author=`git log $commit_id -n 1 --format="%an"`
						email=`git log $commit_id -n 1 --format="%ae"`
						cr=`git log $commit_id -n 1 --format="%s" | grep -aoe "IK[A-Z]*-[0-9]*"`
						cr_url="https://idart.mot.com/browse/$cr"
						assign=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.assignee.displayName`
						description=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.summary`
						components=`curl -u gaoyx9:gyx050400?? -X GET http://idart.mot.com/rest/api/2/issue/$cr | jq .fields.components[0].name`
                    cd -
                fi
                echo "<tr><td>$commit_id</td><td>$subject</td><td>$author</br>($eamil)</td><td><a href="$cr_url">$cr</a></td><td>$description</td><td>$components</td><td>$assign</td></tr>" >> change_list.html
            fi
        done
    fi
done
echo $html_tail >> change_list.html
}

get_commit_msg
