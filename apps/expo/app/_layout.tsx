import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
export default function Layout() {
  return (
    <>
      <Stack>
        <Stack.Screen name="index" options={{ title: 'silentdrop' }} />
      </Stack>
      <StatusBar style="auto" />
    </>
  );
}
