import React, { useEffect, useState } from "react";
import { Alert, Button, Image, SafeAreaView, ScrollView, StatusBar, StyleSheet, Text, TouchableOpacity, View } from "react-native";
import * as Camera from "expo-camera";
import { BarCodeScanner } from "expo-barcode-scanner";
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import * as Notifications from "expo-notifications";
import AsyncStorage from "@react-native-async-storage/async-storage";

// ====== CONFIGURATION ======
const BACKGROUND_TASK_NAME = "BACKGROUND_LOCATION_TASK";
const PROXIMITY_METERS = 80; // distance threshold for notification
// ===========================

// Background task for location tracking
TaskManager.defineTask(BACKGROUND_TASK_NAME, async ({ data, error }) => {
  if (error) {
    console.error(error);
    return;
  }
  if (data) {
    const { locations } = data;
    console.log("Background location:", locations);
  }
});

export default function App() {
  const [hasCameraPermission, setHasCameraPermission] = useState(null);
  const [hasScannerPermission, setHasScannerPermission] = useState(null);
  const [hasLocationPermission, setHasLocationPermission] = useState(null);
  const [cameraRef, setCameraRef] = useState(null);
  const [captures, setCaptures] = useState([]);
  const [mode, setMode] = useState("camera"); // 'camera' or 'barcode'

  useEffect(() => {
    (async () => {
      const { status } = await Camera.requestCameraPermissionsAsync();
      setHasCameraPermission(status === "granted");
      const { status: scStatus } = await BarCodeScanner.requestPermissionsAsync();
      setHasScannerPermission(scStatus === "granted");
      const loc = await Location.requestForegroundPermissionsAsync();
      setHasLocationPermission(loc.status === "granted");
      await Notifications.requestPermissionsAsync();

      const raw = await AsyncStorage.getItem("@route_state");
      if (raw) {
        try {
          const s = JSON.parse(raw);
          setCaptures(s.stops || []);
        } catch (e) {
          console.warn("failed to parse saved state", e);
        }
      }
    })();
  }, []);

  // Save state
  async function persistState(stops) {
    const obj = { stops };
    await AsyncStorage.setItem("@route_state", JSON.stringify(obj));
  }

  // Capture photo (OCR placeholder)
  async function takePhotoAndOcr() {
    if (!cameraRef) return;
    const photo = await cameraRef.takePictureAsync({ base64: true, quality: 0.6 });
    const id = Math.random().toString(36).slice(2);
    const text = "(placeholder OCR)";
    const newStop = { id, uri: photo.uri, text, delivered: false };
    const updated = [...captures, newStop];
    setCaptures(updated);
    await persistState(updated);
  }

  // Barcode scan handler
  async function handleBarCodeScanned({ type, data }) {
    setMode("camera");
    const id = Math.random().toString(36).slice(2);
    const newStop = { id, barcode: data, type, delivered: false };
    const updated = [...captures, newStop];
    setCaptures(updated);
    await persistState(updated);
    Alert.alert("Barcode scanned", `Type: ${type}\nData: ${data}`);
  }

  // Mark as delivered
  async function markDelivered(index) {
    const updated = [...captures];
    updated[index].delivered = true;
    setCaptures(updated);
    await persistState(updated);
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" />
      <ScrollView contentContainerStyle={{ padding: 16 }}>
        <Text style={styles.title}>Postal Route — Starter</Text>

        {/* Camera or Barcode Scanner */}
        <View style={styles.card}>
          <Text style={styles.h}>Scanner Mode</Text>
          {mode === "camera" ? (
            <Camera.Camera style={{ height: 300 }} ref={(r) => setCameraRef(r)} />
          ) : (
            <BarCodeScanner onBarCodeScanned={handleBarCodeScanned} style={{ height: 300 }} />
          )}
          <View style={{ flexDirection: "row", gap: 8, marginTop: 8 }}>
            {mode === "camera" && (
              <TouchableOpacity style={styles.btn} onPress={takePhotoAndOcr}>
                <Text style={styles.btnText}>Capture + OCR</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity style={styles.btnAlt} onPress={() => setMode(mode === "camera" ? "barcode" : "camera")}>
              <Text>{mode === "camera" ? "Switch to Barcode" : "Switch to Camera"}</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Stops list */}
        <View style={styles.card}>
          <Text style={styles.h}>Stops ({captures.length})</Text>
          {captures.map((s, i) => (
            <View key={s.id} style={styles.stopRow}>
              {s.uri && <Image source={{ uri: s.uri }} style={styles.thumb} />}
              <View style={{ flex: 1 }}>
                {s.barcode && <Text>Barcode: {s.barcode}</Text>}
                {s.text && <Text>{s.text}</Text>}
              </View>
              <View style={{ justifyContent: "center" }}>
                <TouchableOpacity style={styles.smallBtn} onPress={() => markDelivered(i)}>
                  <Text style={{ color: "white" }}>Delivered</Text>
                </TouchableOpacity>
              </View>
            </View>
          ))}
        </View>

        <View style={{ height: 60 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff" },
  title: { fontSize: 20, fontWeight: "600", marginBottom: 12 },
  card: { backgroundColor: "#f9fafb", padding: 12, borderRadius: 12, marginBottom: 12 },
  h: { fontSize: 16, fontWeight: "600", marginBottom: 8 },
  btn: { backgroundColor: "#0ea5a4", padding: 10, borderRadius: 10 },
  btnText: { color: "white", fontWeight: "600" },
  btnAlt: { backgroundColor: "#e2e8f0", padding: 10, borderRadius: 10 },
  stopRow: { flexDirection: "row", gap: 8, marginBottom: 8, alignItems: "center" },
  thumb: { width: 80, height: 80, borderRadius: 8, backgroundColor: "#ddd" },
  smallBtn: { backgroundColor: "#15803d", padding: 8, borderRadius: 8 }
});
