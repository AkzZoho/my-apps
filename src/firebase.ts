import { initializeApp, getApps } from "firebase/app";
import { getDatabase } from "firebase/database";

const firebaseConfig = {
  apiKey: "AIzaSyAozpBL9WdENY1fo7XBws-4d_n9H-417x8",
  authDomain: "projectkuri-c284d.firebaseapp.com",
  databaseURL: "https://projectkuri-c284d-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "projectkuri-c284d",
  storageBucket: "projectkuri-c284d.firebasestorage.app",
  messagingSenderId: "638627598431",
  appId: "1:638627598431:web:c1201144f3399be0544bea",
};

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
export const database = getDatabase(app);
