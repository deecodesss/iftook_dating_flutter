class AppConstants {
  // static const URL = "https://iftookbackendcopy.vercel.app"; // DEV URL

  static const URL = "http://localhost:3000"; // Local URL
  // static const URL = "https://iftookrender.onrender.com"; // Render URL

  static const BASE_URL = '$URL/api';

  // For socket connection, we need the base URL, not the API URL
  // Socket.io connections don't need the '/socket.io' path - the client adds it automatically
  static const SOCKET_URL = URL;
}
