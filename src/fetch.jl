
function fetch_message()
    url = "https://raw.githubusercontent.com/ComputationalThermodynamics/repositories_pictures/main/MAGEMinApp/message.txt"

    try
        # Perform the HTTP GET request
        response = HTTP.get(url)
        
        # Check if the request was successful
        if response.status == 200
            # Convert the response body to a string
            text_content = String(response.body)
            return text_content
        else
            return "Failed to retrieve the text file. Status code: " * string(response.status)
        end
    catch e
        return ""
    end
end

function fetch_message2()
    url = "https://raw.githubusercontent.com/ComputationalThermodynamics/repositories_pictures/main/MAGEMinApp/message2.txt"

    try
        # Perform the HTTP GET request
        response = HTTP.get(url)
        
        # Check if the request was successful
        if response.status == 200
            # Convert the response body to a string
            text_content = String(response.body)
            return text_content
        else
            return "Failed to retrieve the text file. Status code: " * string(response.status)
        end
    catch e
        return " "
    end
end

