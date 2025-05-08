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
    
    // Creates a client that authenticates with DefaultAzureCredential
    BlobServiceClient blobServiceClient = new BlobServiceClient(new Uri(envVars["BLOB_STORAGE_URL"]), new DefaultAzureCredential());

    // CREATE A CONTAINER

    //Create a unique name for the container
    string containerName = "wtblob" + Guid.NewGuid().ToString();

    // Create the container and return a container client object
    Console.WriteLine("Creating container: " + containerName);
    BlobContainerClient containerClient = await blobServiceClient.CreateBlobContainerAsync(containerName);
    
    // Check if the container was created successfully
    if (containerClient != null)
    {
        Console.WriteLine("Container created successfully, press 'Enter' to continue.");
        Console.ReadLine();
    }
    else
    {
        Console.WriteLine("Failed to create the container, exiting program.");
        return;
    }

    // CREATE A LOCAL FILE FOR UPLOAD TO BLOB STORAGE
    
    // Create a local file in the ./data/ directory for uploading and downloading
    string localPath = "./data/";
    string fileName = "wtfile" + Guid.NewGuid().ToString() + ".txt";
    string localFilePath = Path.Combine(localPath, fileName);

    // Write text to the file
    await File.WriteAllTextAsync(localFilePath, "Hello, World!");

    // UPLOAD THE FILE TO BLOB STORAGE
    
    // Get a reference to the blob and upload the file
    BlobClient blobClient = containerClient.GetBlobClient(fileName);

    Console.WriteLine("Uploading to Blob storage as blob:\n\t {0}\n", blobClient.Uri);

    // Open the file and upload its data
    using (FileStream uploadFileStream = File.OpenRead(localFilePath))
    {
        await blobClient.UploadAsync(uploadFileStream);
        uploadFileStream.Close();
    }

    // Verify if the file was uploaded successfully
    bool blobExists = await blobClient.ExistsAsync();
    if (blobExists)
    {
        Console.WriteLine("File uploaded successfully, press 'Enter' to continue.");
        Console.ReadLine();
    }
    else
    {
        Console.WriteLine("File upload failed, exiting program..");
        return;
    }

    // LIST THE CONTAINER'S BLOBS

    // List blobs in the container
    Console.WriteLine("Listing blobs...");
    await foreach (BlobItem blobItem in containerClient.GetBlobsAsync())
    {
        Console.WriteLine("\t" + blobItem.Name);
    }

    Console.WriteLine("Press 'Enter' to continue.");
    Console.ReadLine();

    // DOWNLOAD THE BLOB TO A LOCAL FILE
    
    // Add the string "DOWNLOADED" before the .txt extension so it doesn't 
    // overwrite the original file

    string downloadFilePath = localFilePath.Replace(".txt", "DOWNLOADED.txt");

    Console.WriteLine("\nDownloading blob to\n\t{0}\n", downloadFilePath);

    // Download the blob's contents and save it to a file
    BlobDownloadInfo download = await blobClient.DownloadAsync();

    using (FileStream downloadFileStream = File.OpenWrite(downloadFilePath))
    {
        await download.Content.CopyToAsync(downloadFileStream);
    }
    
    Console.WriteLine("\nLocate the local file in the data directory created earlier \n" +
    "to verify it was downloaded.");
    Console.WriteLine("Press 'Enter' to continue.");
    Console.ReadLine();

    // DELETE THE BLOB AND CONTAINER

    // Delete the container and the local files
    Console.WriteLine("\n\nDeleting blob container...");
    await containerClient.DeleteAsync();

    Console.WriteLine("Deleting the local source and downloaded files...");
    File.Delete(localFilePath);
    File.Delete(downloadFilePath);

    Console.WriteLine("Finished cleaning up.");

}