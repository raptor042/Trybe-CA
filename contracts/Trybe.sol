// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

// Building a personalized memory built on base
// Create fun, join and never forget.

// An album is a collection of photos and videos that reflect a person's experience with them and other people.
// A trybe album expands it to help you access the whole album capturing not just your own experience but also others.

contract Trybe {
    address public owner;
    uint256 public totalNoOfAlbumsCreated;
    uint private fee;

    struct Image {
        uint256 id; // Identify this image by a unique number
        string url; // Carries the url of this image stored in IPFS
        string description; // Description of the image
        address owner; // The address of the participant that posted it
        uint256 created; // Timestamp when the memory was created
        uint256 fee;
    }

    struct Album {
        uint256 id;
        bool visibility; // "public == true" or "private == false"
        uint256 fee; // Fee to join or access images in a private album
        address owner; // Owner of the album
        string name; // Name of the album
        string description; // Description of the memory
        string profileImage; // Profile image of the memory
        uint256 created; // Timestamp when the memory was created
        address[] participants; // Wallet address of each participant
        uint256 totalNoOfImages; // Total number of images in the album
    }

    Album[] private albums;

    mapping (uint256 => Album) private album;
    mapping (address => string[]) private images;
    mapping (uint256 => mapping (uint256 => Image)) private imagesInAlbum; // Map album ID to images

    event Upload(address indexed user, string url, uint256 createdAt);
    event AlbumCreated(address indexed creator, string nameOfAlbum, uint256 albumId);
    event JoinedAlbum(address indexed participant, uint256 timeJoined);
    event ImageAdded(uint256 albumId, uint256 imageId);
    event ImageDownloaded(uint256 albumId, uint256 imageId);

    constructor(uint _fee) {
        owner = msg.sender;
        totalNoOfAlbumsCreated = 0;
        fee = _fee;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    function upload(string memory url) public {
        require(msg.sender != address(0), "No zero addresses allowed.");
        require(bytes(url).length > 0, "Please add a url.");

        images[msg.sender].push(url);

        emit Upload(msg.sender, url, block.timestamp);
    }

    function getImages() public view returns (string[] memory) {
        return images[msg.sender];
    }

    function getAlbums() public view returns (Album[] memory) {
        uint256 count = 0;
        
        // Determine the size of _albums array
        for (uint256 x = 0; x < albums.length; x++) {
            for (uint256 y = 0; y < albums[x].participants.length; y++) {
                if (albums[x].participants[y] == msg.sender) {
                    count++;
                    break; // break the inner loop as soon as participant found
                }
            }
        }
        
        // Create _albums array with the correct size
        Album[] memory _albums = new Album[](count);
        uint256 index = 0;

        // Populate _albums array with albums where msg.sender is a participant
        for (uint256 x = 0; x < albums.length; x++) {
            for (uint256 y = 0; y < albums[x].participants.length; y++) {
                if (albums[x].participants[y] == msg.sender) {
                    _albums[index] = albums[x];
                    index++;
                    break; // break the inner loop as soon as participant found
                }
            }
        }
        
        return _albums;
    }

    function createAlbum(
        string memory _name,
        string memory description,
        address[] memory _participants,
        string memory _image,
        bool visibility,
        uint256 _fee
    ) public {
        require(msg.sender != address(0), "No zero addresses allowed.");
        require(bytes(_name).length > 0, "Please add a name.");
        require(bytes(description).length > 0, "Describe your album to let the world know how you felt when you created this.");

        totalNoOfAlbumsCreated++;

        address[] memory participants = new address[](_participants.length + 1);
        for (uint256 i = 0; i < _participants.length; i++) {
            participants[i] = _participants[i];
        }
        participants[_participants.length] = msg.sender;

        Album storage _album = album[totalNoOfAlbumsCreated];
        _album.id = totalNoOfAlbumsCreated;
        _album.visibility = visibility;
        _album.fee = visibility ? 0 : (_fee * 1 ether) / 1000;
        _album.owner = msg.sender;
        _album.name = _name;
        _album.description = description;
        _album.profileImage = _image;
        _album.created = block.timestamp;
        _album.participants = participants;
        _album.totalNoOfImages = 0;

        albums.push(_album);

        emit AlbumCreated(msg.sender, _name, totalNoOfAlbumsCreated);
    }

    function joinAlbum(uint256 albumId) public payable {
        require(albumId > 0 && albumId <= totalNoOfAlbumsCreated, "This album does not exist");

        Album storage _album = album[albumId];
        require(_album.visibility || msg.value >= _album.fee, "This is a private album.");
        
        _album.participants.push(msg.sender);

        for (uint i = 0; i < albums.length; i++) {
            if(albums[i].id == albumId) {
                albums[i].participants.push(msg.sender);
                break;
            }
        }

        if (_album.visibility) {
            uint256 _fee = (fee * msg.value) / 100;
            uint256 balance = msg.value - _fee;

            (bool os, ) = payable(_album.owner).call{value: balance}("");
            require(os, "Fee payment to album owner failed.");

            (bool os1, ) = payable(owner).call{value: _fee}("");
            require(os1, "Fee payment to trybe owner failed.");
        }

        emit JoinedAlbum(msg.sender, block.timestamp);
    }

    function addImageToAlbum(
        uint256 albumId,
        string memory _url,
        string memory _description,
        uint256 _fee
    ) public {
        require(albumId > 0 && albumId <= totalNoOfAlbumsCreated, "This album does not exist");

        Album storage _album = album[albumId];
        _album.totalNoOfImages++;

        bool isParticipant = false;
        for (uint256 i = 0; i < _album.participants.length; i++) {
            if (_album.participants[i] == msg.sender) {
                isParticipant = true;
                break;
            }
        }
        require(isParticipant, "Only those who have joined the album can add an image.");

        imagesInAlbum[albumId][_album.totalNoOfImages] = Image({
            owner: msg.sender,
            id: _album.totalNoOfImages,
            url: _url,
            description: _description,
            created: block.timestamp,
            fee: _album.visibility ? 0 : (_fee * 1 ether) / 100
        });

        for (uint i = 0; i < albums.length; i++) {
            if(albums[i].id == albumId) {
                albums[i].totalNoOfImages++;
                break;
            }
        }

        emit ImageAdded(albumId, _album.totalNoOfImages);
    }

    function getAlbum(uint256 albumId) public view returns (Album memory) {
        require(albumId > 0 && albumId <= totalNoOfAlbumsCreated, "This album does not exist");

        return album[albumId];
    }

    function getImagesInAlbum(uint256 albumId) public view returns (Image[] memory) {
        require(albumId > 0 && albumId <= totalNoOfAlbumsCreated, "This album does not exist");
        Album storage _album = album[albumId];

        bool isParticipant = false;
        for (uint256 i = 0; i < album[albumId].participants.length; i++) {
            if (album[albumId].participants[i] == msg.sender) {
                isParticipant = true;
                break;
            }
        }
        require(isParticipant, "Only those who have joined the album see the album.");

        Image[] memory _images = new Image[](_album.totalNoOfImages);
        for (uint256 i = 1; i <= _album.totalNoOfImages; i++) {
            _images[i - 1] = imagesInAlbum[albumId][i];
        }
        return _images;
    }

    function getImageInAlbum(uint256 albumId, uint256 imageId) public view returns (Image memory) {
        require(albumId > 0 && albumId <= totalNoOfAlbumsCreated, "This album does not exist");
        require(imageId > 0 && imageId <= album[albumId].totalNoOfImages, "This image does not exist");

        bool isParticipant = false;
        for (uint256 i = 0; i < album[albumId].participants.length; i++) {
            if (album[albumId].participants[i] == msg.sender) {
                isParticipant = true;
                break;
            }
        }
        require(isParticipant, "Only those who have joined the album see the album.");

        return imagesInAlbum[albumId][imageId];
    }

    function download(uint256 albumId, uint256 imageId) public payable {
        require(albumId > 0 && albumId <= totalNoOfAlbumsCreated, "This album does not exist");

        Album storage _album = album[albumId];
        Image storage _image = imagesInAlbum[albumId][imageId];
        require(_album.visibility || msg.value >= _image.fee, "This is a private album image.");

        uint256 _fee = (fee * msg.value) / 100;
        uint256 balance = msg.value - _fee;

        (bool os, ) = payable(_album.owner).call{value: balance}("");
        require(os, "Fee payment to album owner failed.");

        (bool os1, ) = payable(owner).call{value: _fee}("");
        require(os1, "Fee payment to trybe owner failed.");

        emit ImageDownloaded(albumId, imageId);
    }

    function getListofParticipants(uint256 albumId) public view returns (address[] memory) {
        require(albumId > 0 && albumId <= totalNoOfAlbumsCreated, "This album does not exist");
        return album[albumId].participants;
    }
}
