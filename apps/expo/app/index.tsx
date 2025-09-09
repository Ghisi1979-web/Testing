import React from 'react';
import { View, Text, Button } from 'react-native';
import Constants from 'expo-constants';
import { createClient } from '@supabase/supabase-js';

const { SUPABASE_URL, SUPABASE_ANON_KEY, SAFE_MODE_FOR_REVIEW, EXPLICIT_FEATURE_FLAG, ALLOWED_COUNTRIES_EXPLICIT } = Constants.expoConfig?.extra as any;
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export default function Home() {
  const [session, setSession] = React.useState<any>(null);
  const safeMode = String(SAFE_MODE_FOR_REVIEW) === 'true';
  const explicitEnabled = String(EXPLICIT_FEATURE_FLAG) === 'true' && !safeMode;

  React.useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub?.subscription?.unsubscribe();
  }, []);

  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 16 }}>
      <Text style={{ fontSize: 24, fontWeight: '700' }}>silentdrop</Text>
      <Text>Safe Mode: {safeMode ? 'ON' : 'OFF'}</Text>
      <Text>Explicit Features: {explicitEnabled ? 'ENABLED' : 'DISABLED'}</Text>
      {!session ? (
        <Button title="Sign In (magic link)" onPress={async () => {
          const email = prompt('Email');
          if (!email) return;
          await supabase.auth.signInWithOtp({ email });
          alert('Check your email');
        }} />
      ) : (
        <Button title="Sign Out" onPress={() => supabase.auth.signOut()} />
      )}
    </View>
  );
}

