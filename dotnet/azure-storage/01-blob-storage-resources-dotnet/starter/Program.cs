using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Identity;
using dotenv.net;


// Load environment variables from .env file and assign
DotEnv.Load();
var envVars = DotEnv.Read();

// Run the examples asynchronously, wait for the results before proceeding
ProcessAsync().GetAwaiter().GetResult();

Console.WriteLine("Press enter to exit the sample application.");
Console.ReadLine();

async Task ProcessAsync()
{

    Console.WriteLine("Azure Blob Storage exercise\n");

    // CREATE A BLOB STORAGE CLIENT
    

    // CREATE A CONTAINER



    // CREATE A LOCAL FILE FOR UPLOAD TO BLOB STORAGE
    

    // UPLOAD THE FILE TO BLOB STORAGE
    


    // LIST THE CONTAINER'S BLOBS


    // DOWNLOAD THE BLOB TO A LOCAL FILE
    

    // DELETE THE BLOB AND CONTAINER


}