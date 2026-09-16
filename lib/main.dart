import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final FlutterTts flutterTts = FlutterTts();

// ============================================================
// VOICE SERVICE
// ============================================================

class VoiceService {
  static Future<void> speak(
    String text,
    String language,
  ) async {
    try {
      await flutterTts.stop();
      await flutterTts.setLanguage(language);
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      await flutterTts.speak(text);
    } catch (e) {
      debugPrint('Voice error: $e');
    }
  }

  static Future<void> stop() async {
    await flutterTts.stop();
  }
}

// ============================================================
// SPEECH-TO-TEXT SERVICE
// ============================================================

class SpeechService {
  final stt.SpeechToText speech = stt.SpeechToText();

  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    return speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
    );
  }

  Future<void> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    await speech.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  Future<void> stop() async {
    await speech.stop();
  }

  Future<void> cancel() async {
    await speech.cancel();
  }

  void dispose() {
    speech.cancel();
  }
}

// ============================================================
// MAIN
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Phase 9: keep Firestore data available offline on mobile.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const DementiaCareApp());
}

// ============================================================
// APP
// ============================================================

class DementiaCareApp extends StatelessWidget {
  const DementiaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dementia Care',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D5B),
        ),
        scaffoldBackgroundColor:
            const Color(0xFFEAF6EF),
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
// LANGUAGE DATA
// ============================================================

class AppLanguage {
  final String name;
  final String code;

  const AppLanguage({
    required this.name,
    required this.code,
  });
}

const AppLanguage english = AppLanguage(
  name: 'English',
  code: 'en-US',
);

const AppLanguage tamil = AppLanguage(
  name: 'Tamil',
  code: 'ta-IN',
);

const AppLanguage hindi = AppLanguage(
  name: 'Hindi',
  code: 'hi-IN',
);


// ============================================================
// FIREBASE AUTHENTICATION - LOGIN PAGE
// ============================================================

class LoginPage extends StatefulWidget {
  final String role;

  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  String get expectedEmail => widget.role == 'Patient'
      ? 'patient001@test.com'
      : 'caregiver001@test.com';

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    if (email.toLowerCase() != expectedEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please use the registered ${widget.role.toLowerCase()} account for this role.'),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.role == 'Patient'
              ? const PatientPage()
              : const CaregiverPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        case 'user-not-found':
          message = 'User not found.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Try again later.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = widget.role == 'Patient';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.role} Login',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D5B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D5B),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPatient ? Icons.person_rounded : Icons.people_alt_rounded,
                  color: Colors.white,
                  size: 55,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.role} Login',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245B45),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dementia Care',
                style: TextStyle(fontSize: 19, color: Color(0xFF4F6F60)),
              ),
              const SizedBox(height: 35),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_rounded, size: 28),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_rounded, size: 28),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () {
                      setState(() => obscurePassword = !obscurePassword);
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : login,
                  icon: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded, size: 28),
                  label: Text(
                    loading ? 'Logging in...' : 'Login',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                isPatient ? 'Patient account' : 'Caregiver account',
                style: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF5A7769),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D5B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 55,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Dementia Care',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245B45),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Care ~ Memory ~ Happiness',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF4F6F60),
                  ),
                ),

                const SizedBox(height: 45),

                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginPage(role: 'Patient'),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.person_rounded,
                      size: 30,
                    ),
                    label: const Text(
                      'Patient',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginPage(role: 'Caregiver'),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.people_alt_rounded,
                      size: 30,
                    ),
                    label: const Text(
                      'Caregiver',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 45),

                const Text(
                  'Simple ~ Safe ~ Supportive',
                  style: TextStyle(
                    fontSize: 17,
                    color: Color(0xFF5A7769),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PATIENT PAGE
// ============================================================

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});

  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  AppLanguage selectedLanguage = english;

  final SpeechService speechService = SpeechService();
  bool speechEnabled = false;
  bool isListening = false;
  String recognizedText = '';

  String get selectedCode => selectedLanguage.code;

  String get welcomeText {
    if (selectedLanguage == tamil) {
      return 'வணக்கம். உங்கள் நினைவாற்றலை மேம்படுத்தும் செயல்பாடுகள் இங்கே உள்ளன.';
    }
    if (selectedLanguage == hindi) {
      return 'नमस्ते। आपकी याददाश्त को बेहतर बनाने के लिए गतिविधियाँ यहाँ हैं।';
    }
    return 'Welcome. Cognitive activities to support your memory are available here.';
  }

  String get voiceHelpText {
    if (selectedLanguage == tamil) {
      return 'வாய்ஸ் உதவியைப் பயன்படுத்த இந்த பொத்தானை அழுத்தவும்.';
    }
    if (selectedLanguage == hindi) {
      return 'वॉइस सहायता का उपयोग करने के लिए इस बटन को दबाएँ।';
    }
    return 'Use voice assistance to hear guidance and speak commands.';
  }

  String get listenText {
    if (selectedLanguage == tamil) return 'கேட்க';
    if (selectedLanguage == hindi) return 'सुनें';
    return 'Listen';
  }

  String get speakText {
    if (selectedLanguage == tamil) return 'பேசவும்';
    if (selectedLanguage == hindi) return 'बोलें';
    return 'Speak';
  }

  String get stopListeningText {
    if (selectedLanguage == tamil) return 'கேட்பதை நிறுத்தவும்';
    if (selectedLanguage == hindi) return 'सुनना बंद करें';
    return 'Stop Listening';
  }

  String get recognizedTextLabel {
    if (selectedLanguage == tamil) return 'அறிந்த குரல்';
    if (selectedLanguage == hindi) return 'पहचानी गई आवाज़';
    return 'Recognized Speech';
  }

  String get languageLabel {
    if (selectedLanguage == tamil) return 'மொழி';
    if (selectedLanguage == hindi) return 'भाषा';
    return 'Language';
  }

  String get completeText {
    if (selectedLanguage == tamil) return 'முடிந்தது';
    if (selectedLanguage == hindi) return 'पूरा हुआ';
    return 'Completed';
  }

  String get pendingText {
    if (selectedLanguage == tamil) return 'நிலுவையில்';
    if (selectedLanguage == hindi) return 'बाकी';
    return 'Pending';
  }

  Future<void> initializeSpeech() async {
    final available = await speechService.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => isListening = status == 'listening');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => isListening = false);
      },
    );

    if (!mounted) return;
    setState(() => speechEnabled = available);
  }

  Future<void> startListening() async {
    if (!speechEnabled) await initializeSpeech();
    if (!speechEnabled) return;

    setState(() {
      isListening = true;
      recognizedText = '';
    });

    await speechService.listen(
      localeId: selectedCode,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => recognizedText = text);
        if (isFinal && text.trim().isNotEmpty) {
          speakVoiceResponse();
        }
      },
    );
  }

  Future<void> stopListening() async {
    await speechService.stop();
    if (!mounted) return;
    setState(() => isListening = false);
  }

  Future<void> speakVoiceResponse() async {
    String response;
    if (selectedLanguage == tamil) {
      response = 'உங்கள் குரலை கேட்டேன். நினைவாற்றல் செயல்பாடுகள் மற்றும் நினைவூட்டல்களை பயன்படுத்தலாம்.';
    } else if (selectedLanguage == hindi) {
      response = 'मैंने आपकी आवाज़ सुनी। आप स्मृति गतिविधियों और रिमाइंडर का उपयोग कर सकते हैं।';
    } else {
      response = 'I heard you. You can use the memory activities and reminders.';
    }
    await VoiceService.speak(response, selectedCode);
  }

  Future<void> speakWelcome() async {
    await VoiceService.speak(welcomeText, selectedCode);
  }

  Future<void> speakReminder(String title, String type) async {
    String text;
    if (selectedLanguage == tamil) {
      if (type == 'Medicine') {
        text = '$title. மருந்து எடுத்துக்கொள்ள வேண்டிய நேரம்.';
      } else if (type == 'Hydration') {
        text = '$title. தண்ணீர் குடிக்க வேண்டிய நேரம்.';
      } else if (type == 'Appointment') {
        text = '$title. மருத்துவ சந்திப்பு நினைவூட்டல்.';
      } else {
        text = '$title. உங்கள் தினசரி செயல்பாட்டை செய்யவும்.';
      }
    } else if (selectedLanguage == hindi) {
      if (type == 'Medicine') {
        text = '$title. दवा लेने का समय है।';
      } else if (type == 'Hydration') {
        text = '$title. पानी पीने का समय है।';
      } else if (type == 'Appointment') {
        text = '$title. यह आपकी चिकित्सा अपॉइंटमेंट की याद दिलाता है।';
      } else {
        text = '$title. अपनी दैनिक गतिविधि पूरी करें।';
      }
    } else {
      if (type == 'Medicine') {
        text = '$title. It is time to take your medicine.';
      } else if (type == 'Hydration') {
        text = '$title. It is time to drink water.';
      } else if (type == 'Appointment') {
        text = '$title. This is your medical appointment reminder.';
      } else {
        text = '$title. Please complete your daily activity.';
      }
    }
    await VoiceService.speak(text, selectedCode);
  }

  Future<void> completeReminder(String reminderId, String title, String type) async {
    try {
      await FirebaseFirestore.instance.collection('reminders').doc(reminderId).update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('activity_logs').add({
        'patientId': 'patient001',
        'activity': 'Reminder Completed',
        'details': title,
        'type': type,
        'status': 'Completed',
        'duration': 0,
        'timestamp': FieldValue.serverTimestamp(),
      'clientTimestamp': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title - $completeText')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update reminder. Please try again.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    initializeSpeech();
  }

  @override
  void dispose() {
    speechService.dispose();
    super.dispose();
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFFD7EDE1),
                        child: Icon(Icons.person_rounded, size: 36, color: Color(0xFF2E7D5B)),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          selectedLanguage == tamil ? 'வணக்கம்!' : selectedLanguage == hindi ? 'नमस्ते!' : 'Welcome!',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF245B45)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              const Text('Cognitive Activities', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF245B45))),
              const SizedBox(height: 14),
              GameCard(
                icon: Icons.grid_view_rounded,
                title: 'Memory Match',
                subtitle: 'Match the same pictures',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemoryMatchGame(language: selectedLanguage))),
              ),
              GameCard(
                icon: Icons.search_rounded,
                title: 'Find & Match',
                subtitle: 'Find the correct answer',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FindMatchGame(language: selectedLanguage))),
              ),
              GameCard(
                icon: Icons.pattern_rounded,
                title: 'Pattern Game',
                subtitle: 'Remember the correct pattern',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatternGame(language: selectedLanguage))),
              ),
              const SizedBox(height: 20),

              Text(languageLabel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF245B45))),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: DropdownButtonFormField<AppLanguage>(
                    initialValue: selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Select Language',
                      prefixIcon: Icon(Icons.language_rounded, size: 28),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: english, child: Text('English', style: TextStyle(fontSize: 18))),
                      DropdownMenuItem(value: tamil, child: Text('தமிழ்', style: TextStyle(fontSize: 18))),
                      DropdownMenuItem(value: hindi, child: Text('हिन्दी', style: TextStyle(fontSize: 18))),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedLanguage = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.record_voice_over_rounded, size: 34, color: Color(0xFF2E7D5B)),
                          SizedBox(width: 12),
                          Text('Voice Help', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF245B45))),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(voiceHelpText, style: const TextStyle(fontSize: 18, height: 1.4)),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: speakWelcome,
                          icon: const Icon(Icons.volume_up_rounded, size: 28),
                          label: Text(listenText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: isListening ? stopListening : startListening,
                          icon: Icon(isListening ? Icons.stop_circle_rounded : Icons.mic_rounded, size: 28),
                          label: Text(isListening ? stopListeningText : speakText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6EF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD7EDE1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(recognizedTextLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF245B45))),
                            const SizedBox(height: 8),
                            Text(
                              recognizedText.isEmpty ? 'Speak clearly after pressing the microphone.' : recognizedText,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text("Today's Reminders", style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF245B45))),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reminders').where('patientId', isEqualTo: 'patient001').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const InfoCard(icon: Icons.notifications_none_rounded, title: 'No reminders', subtitle: 'You have no reminders for today');
                  }

                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title']?.toString() ?? 'Reminder';
                      final type = data['type']?.toString() ?? 'Activity';
                      final completed = data['completed'] == true;

                      IconData icon = Icons.notifications_rounded;
                      if (type == 'Medicine') icon = Icons.medication_rounded;
                      if (type == 'Hydration') icon = Icons.water_drop_rounded;
                      if (type == 'Appointment') icon = Icons.local_hospital_rounded;
                      if (type == 'Activity') icon = Icons.calendar_today_rounded;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(icon, size: 32, color: const Color(0xFF2E7D5B)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                                    Text(type, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 5),
                                    Text(
                                      completed ? completeText : pendingText,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: completed ? const Color(0xFF2E7D5B) : Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded, size: 28),
                                onPressed: () => speakReminder(title, type),
                              ),
                              if (!completed)
                                IconButton(
                                  tooltip: 'Mark completed',
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 30),
                                  onPressed: () => completeReminder(doc.id, title, type),
                                )
                              else
                                const Icon(Icons.check_circle_rounded, size: 30, color: Color(0xFF2E7D5B)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// GAME CARD
// ============================================================

class GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin:
          const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor:
              const Color(0xFFD7EDE1),
          child: Icon(
            icon,
            size: 30,
            color: const Color(0xFF2E7D5B),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================
// INFO CARD
// ============================================================

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin:
          const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.all(12),
        leading: Icon(
          icon,
          size: 32,
          color: const Color(0xFF2E7D5B),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AI DIFFICULTY SERVICE
// ============================================================

class AiDifficultyService {
  static String difficultyFromAccuracy(
    double accuracy,
  ) {
    if (accuracy < 0.50) {
      return 'Easy';
    } else if (accuracy < 0.80) {
      return 'Medium';
    } else {
      return 'Hard';
    }
  }

  // Adaptive difficulty: move only one level at a time.
  // Low accuracy -> easier, high accuracy -> harder.
  static String calculateNextDifficulty({
    required String currentDifficulty,
    required double accuracy,
  }) {
    if (accuracy < 0.50) {
      if (currentDifficulty == 'Hard') return 'Medium';
      if (currentDifficulty == 'Medium') return 'Easy';
      return 'Easy';
    }

    if (accuracy >= 0.80) {
      if (currentDifficulty == 'Easy') return 'Medium';
      if (currentDifficulty == 'Medium') return 'Hard';
      return 'Hard';
    }

    return currentDifficulty;
  }

  static Future<String>
      getRecommendedDifficulty(
    String gameName,
  ) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('game_results')
              .where(
                'patientId',
                isEqualTo: 'patient001',
              )
              .get();

      final results =
          snapshot.docs.where((doc) {
        final data = doc.data();
        return data['gameName'] ==
            gameName;
      }).toList();

      if (results.isEmpty) {
        return 'Medium';
      }

      results.sort((a, b) {
        final aTime =
            a.data()['timestamp'];
        final bTime =
            b.data()['timestamp'];

        if (aTime is Timestamp &&
            bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }

        return 0;
      });

      final latest =
          results.first.data();

      // Use the previously calculated nextDifficulty so the
      // recommendation shown on the next game launch is the
      // same recommendation saved with the latest result.
      final savedNext =
          latest['nextDifficulty']?.toString();

      if (savedNext == 'Easy' ||
          savedNext == 'Medium' ||
          savedNext == 'Hard') {
        return savedNext!;
      }

      final accuracy =
          (latest['accuracy'] as num?)
                  ?.toDouble() ??
              0.5;

      return difficultyFromAccuracy(
        accuracy,
      );
    } catch (e) {
      debugPrint(
        'AI difficulty error: $e',
      );

      return 'Medium';
    }
  }

  static Future<bool> saveGameResult({
    required String gameName,
    required int score,
    required double accuracy,
    required int attempts,
    required String difficulty,
    required String nextDifficulty,
  }) async {
    final writeFuture = FirebaseFirestore.instance
        .collection('game_results')
        .add({
      'patientId': 'patient001',
      'gameName': gameName,
      'score': score,
      'accuracy': accuracy,
      'attempts': attempts,
      'difficulty': difficulty,
      'nextDifficulty': nextDifficulty,
      'timestamp': FieldValue.serverTimestamp(),
      'clientTimestamp': Timestamp.now(),
    });

    try {
      // Do not make the elderly user wait for a network connection.
      // Firestore keeps the write locally and syncs it later.
      await writeFuture.timeout(
        const Duration(seconds: 2),
      );
      return true;
    } on TimeoutException {
      debugPrint(
        'Game result queued offline and will sync when online.',
      );
      return false;
    } catch (e) {
      debugPrint('Game result save error: $e');
      return false;
    }
  }
}

// ============================================================
// MEMORY MATCH GAME
// ============================================================

class MemoryMatchGame
    extends StatefulWidget {
  final AppLanguage language;

  const MemoryMatchGame({
    super.key,
    required this.language,
  });

  @override
  State<MemoryMatchGame> createState() =>
      _MemoryMatchGameState();
}

class _MemoryMatchGameState
    extends State<MemoryMatchGame> {
  final List<IconData> availableIcons = [
    Icons.home_rounded,
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.phone_rounded,
    Icons.cake_rounded,
    Icons.local_florist_rounded,
  ];

  List<IconData> cards = [];
  List<bool> revealed = [];
  List<bool> matched = [];

  int firstIndex = -1;
  int secondIndex = -1;

  int moves = 0;
  int score = 0;

  String difficulty = 'Medium';
  String nextDifficulty = 'Medium';

  bool busy = false;

  String get languageCode =>
      widget.language.code;

  String get instruction {
    if (widget.language == tamil) {
      return 'ஒரே மாதிரியான படங்களை பொருத்துங்கள்.';
    }

    if (widget.language == hindi) {
      return 'एक जैसी तस्वीरों का मिलान करें।';
    }

    return 'Match the same pictures.';
  }

  @override
  void initState() {
    super.initState();
    loadDifficulty();
  }

  Future<void> loadDifficulty() async {
    final recommended =
        await AiDifficultyService
            .getRecommendedDifficulty(
      'Memory Match',
    );

    if (!mounted) return;

    setState(() {
      difficulty = recommended;
    });

    setupGame();
  }

  int get pairCount {
    if (difficulty == 'Easy') {
      return 3;
    }

    if (difficulty == 'Hard') {
      return 6;
    }

    return 4;
  }

  void setupGame() {
    final selected =
        availableIcons.take(pairCount).toList();

    cards = [
      ...selected,
      ...selected,
    ];

    cards.shuffle(Random());

    revealed =
        List.filled(cards.length, false);

    matched =
        List.filled(cards.length, false);

    firstIndex = -1;
    secondIndex = -1;
    moves = 0;
    score = 0;
    busy = false;

    setState(() {});
  }

  Future<void> speakInstruction() async {
    await VoiceService.speak(
      instruction,
      languageCode,
    );
  }

  Future<void> tapCard(int index) async {
    if (busy ||
        revealed[index] ||
        matched[index]) {
      return;
    }

    setState(() {
      revealed[index] = true;
    });

    if (firstIndex == -1) {
      firstIndex = index;
      return;
    }

    secondIndex = index;
    moves++;

    busy = true;

    await Future.delayed(
      const Duration(
        milliseconds: 600,
      ),
    );

    if (cards[firstIndex] ==
        cards[secondIndex]) {
      matched[firstIndex] = true;
      matched[secondIndex] = true;
      score++;
    } else {
      revealed[firstIndex] = false;
      revealed[secondIndex] = false;
    }

    firstIndex = -1;
    secondIndex = -1;
    busy = false;

    setState(() {});

    if (matched.every(
      (value) => value,
    )) {
      finishGame();
    }
  }

  Future<void> finishGame() async {
    final accuracy =
        (score / pairCount)
            .clamp(0.0, 1.0);

    nextDifficulty =
        AiDifficultyService.calculateNextDifficulty(
      currentDifficulty: difficulty,
      accuracy: accuracy,
    );

    await AiDifficultyService
        .saveGameResult(
      gameName: 'Memory Match',
      score: score,
      accuracy: accuracy,
      attempts: moves,
      difficulty: difficulty,
      nextDifficulty: nextDifficulty,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          'Game Complete',
          style: TextStyle(
            fontSize: 24,
          ),
        ),
        content: Text(
          'Score: $score / $pairCount\n\n'
          'AI Recommendation: '
          '$nextDifficulty',
          style: const TextStyle(
            fontSize: 19,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              setState(() {
                difficulty =
                    nextDifficulty;
              });

              setupGame();
            },
            child: const Text(
              'Play Again',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Memory Match',
          style: TextStyle(
            fontSize: 23,
          ),
        ),
        backgroundColor:
            const Color(0xFF2E7D5B),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Difficulty: $difficulty',
              style: const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Moves: $moves',
              style: const TextStyle(
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    speakInstruction,
                icon: const Icon(
                  Icons.volume_up_rounded,
                  size: 27,
                ),
                label: Text(
                  widget.language == tamil
                      ? 'வழிமுறைகளை கேட்க'
                      : widget.language ==
                              hindi
                          ? 'निर्देश सुनें'
                          : 'Listen to Instructions',
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: GridView.builder(
                itemCount: cards.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      pairCount <= 4
                          ? 3
                          : 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder:
                    (context, index) {
                  final show =
                      revealed[index] ||
                          matched[index];

                  return GestureDetector(
                    onTap: () =>
                        tapCard(index),
                    child: Card(
                      color: show
                          ? Colors.white
                          : const Color(
                              0xFF2E7D5B,
                            ),
                      child: Center(
                        child: show
                            ? Icon(
                                cards[index],
                                size: 45,
                                color:
                                    const Color(
                                  0xFF2E7D5B,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .question_mark_rounded,
                                size: 35,
                                color:
                                    Colors.white,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FIND & MATCH GAME — PICTURE BASED
// ============================================================

class FindMatchGame extends StatefulWidget {
  final AppLanguage language;

  const FindMatchGame({
    super.key,
    required this.language,
  });

  @override
  State<FindMatchGame> createState() => _FindMatchGameState();
}

class _FindMatchGameState extends State<FindMatchGame> {
  final Random random = Random();

  final List<Map<String, dynamic>> pictureBank = [
    {'name': 'Apple', 'icon': Icons.apple_rounded},
    {'name': 'Home', 'icon': Icons.home_rounded},
    {'name': 'Flower', 'icon': Icons.local_florist_rounded},
    {'name': 'Car', 'icon': Icons.directions_car_rounded},
    {'name': 'Dog', 'icon': Icons.pets_rounded},
    {'name': 'Cake', 'icon': Icons.cake_rounded},
    {'name': 'Book', 'icon': Icons.menu_book_rounded},
    {'name': 'Cup', 'icon': Icons.local_cafe_rounded},
    {'name': 'Phone', 'icon': Icons.phone_rounded},
    {'name': 'Sun', 'icon': Icons.wb_sunny_rounded},
  ];

  int currentQuestion = 0;
  int score = 0;
  int attempts = 0;

  String difficulty = 'Medium';
  String nextDifficulty = 'Medium';

  Map<String, dynamic> targetPicture = {};
  List<Map<String, dynamic>> options = [];

  bool answering = false;
  bool gameCompleted = false;
  bool resultSavedOnline = true;

  String get instruction {
    if (widget.language == tamil) {
      return 'மேலே உள்ள படத்தை பார்த்து, அதே படத்தை கீழே தேர்வு செய்யவும்.';
    }

    if (widget.language == hindi) {
      return 'ऊपर दी गई तस्वीर को देखकर नीचे वही तस्वीर चुनें।';
    }

    return 'Look at the picture above and choose the same picture below.';
  }

  String get targetLabel {
    if (widget.language == tamil) {
      return 'இந்த படத்தை கண்டுபிடிக்கவும்';
    }

    if (widget.language == hindi) {
      return 'इस तस्वीर को खोजें';
    }

    return 'Find this picture';
  }

  String get questionLabel {
    if (widget.language == tamil) {
      return 'கேள்வி';
    }

    if (widget.language == hindi) {
      return 'प्रश्न';
    }

    return 'Question';
  }

  String get difficultyLabel {
    if (widget.language == tamil) {
      return 'சிரமம்';
    }

    if (widget.language == hindi) {
      return 'कठिनाई';
    }

    return 'Difficulty';
  }

  @override
  void initState() {
    super.initState();
    generateQuestion();
    loadDifficulty();
  }

  Future<void> loadDifficulty() async {
    final recommended =
        await AiDifficultyService.getRecommendedDifficulty(
      'Find & Match',
    );

    if (!mounted) return;

    setState(() {
      difficulty = recommended;
      generateQuestion();
    });
  }

  int get optionCount {
    if (difficulty == 'Easy') return 3;
    if (difficulty == 'Hard') return 5;
    return 4;
  }

  void generateQuestion() {
    targetPicture =
        pictureBank[random.nextInt(pictureBank.length)];

    final shuffled = List<Map<String, dynamic>>.from(pictureBank)
      ..shuffle(random);

    options = [targetPicture];

    for (final picture in shuffled) {
      if (options.length >= optionCount) break;

      if (picture['name'] != targetPicture['name']) {
        options.add(picture);
      }
    }

    options.shuffle(random);
  }

  Future<void> speakInstruction() async {
    await VoiceService.speak(
      instruction,
      widget.language.code,
    );
  }

  void selectPicture(Map<String, dynamic> selected) {
    if (answering || gameCompleted) return;

    answering = true;
    attempts++;

    if (selected['name'] == targetPicture['name']) {
      score++;
    }

    Future.delayed(
      const Duration(milliseconds: 500),
      () {
        if (!mounted) return;

        if (currentQuestion >= 9) {
          finishGame();
        } else {
          setState(() {
            currentQuestion++;
            answering = false;
            generateQuestion();
          });
        }
      },
    );
  }

  Future<void> finishGame() async {
    if (gameCompleted) return;

    gameCompleted = true;

    final accuracy =
        (score / max(attempts, 1))
            .clamp(0.0, 1.0)
            .toDouble();

    nextDifficulty =
        AiDifficultyService.calculateNextDifficulty(
      currentDifficulty: difficulty,
      accuracy: accuracy,
    );

    resultSavedOnline =
        await AiDifficultyService.saveGameResult(
      gameName: 'Find & Match',
      score: score,
      accuracy: accuracy,
      attempts: attempts,
      difficulty: difficulty,
      nextDifficulty: nextDifficulty,
    );

    if (!mounted) return;

    final saveMessage = resultSavedOnline
        ? 'Your game result has been saved.'
        : 'Your result is saved on this device and will sync when internet returns.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          'Game Completed',
          style: TextStyle(fontSize: 24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: $score / 10',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'AI Recommendation: $nextDifficulty',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D5B),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              saveMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              setState(() {
                difficulty = nextDifficulty;
                currentQuestion = 0;
                score = 0;
                attempts = 0;
                answering = false;
                gameCompleted = false;
                generateQuestion();
              });
            },
            child: const Text(
              'Play Again',
              style: TextStyle(fontSize: 17),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find & Match',
          style: TextStyle(fontSize: 24),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '$difficultyLabel: $difficulty',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '$questionLabel ${currentQuestion + 1} / 10',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Text(
                targetLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6EF),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFD2E9DC),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            targetPicture['icon'] as IconData,
                            size: 92,
                            color: const Color(0xFF2E7D5B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          targetPicture['name'] as String,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: speakInstruction,
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    size: 28,
                  ),
                  label: const Text(
                    'Listen to Instructions',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final picture = options[index];

                  return ElevatedButton(
                    onPressed: answering
                        ? null
                        : () => selectPicture(picture),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          picture['icon'] as IconData,
                          size: 64,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          picture['name'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              Text(
                'Score: $score',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PATTERN GAME
// ============================================================

class PatternGame extends StatefulWidget {
  final AppLanguage language;
  const PatternGame({super.key, required this.language});
  @override
  State<PatternGame> createState() => _PatternGameState();
}

class _PatternGameState extends State<PatternGame> {
  final Random random = Random();

  final List<Map<String, dynamic>> pictureBank = [
    {'name': 'Apple', 'icon': Icons.apple_rounded},
    {'name': 'Home', 'icon': Icons.home_rounded},
    {'name': 'Flower', 'icon': Icons.local_florist_rounded},
    {'name': 'Car', 'icon': Icons.directions_car_rounded},
    {'name': 'Dog', 'icon': Icons.pets_rounded},
    {'name': 'Cake', 'icon': Icons.cake_rounded},
    {'name': 'Book', 'icon': Icons.menu_book_rounded},
    {'name': 'Cup', 'icon': Icons.local_cafe_rounded},
    {'name': 'Phone', 'icon': Icons.phone_rounded},
    {'name': 'Sun', 'icon': Icons.wb_sunny_rounded},
  ];

  int currentQuestion = 0;
  int score = 0;
  int attempts = 0;
  String difficulty = 'Medium';
  String nextDifficulty = 'Medium';
  bool answering = false;
  bool gameCompleted = false;

  List<Map<String, dynamic>> sequence = [];
  Map<String, dynamic>? correctPicture;
  List<Map<String, dynamic>> answerOptions = [];

  String get instruction {
    if (widget.language == tamil) {
      return 'படங்களின் வரிசையை கவனித்து அடுத்த படத்தை தேர்வு செய்யவும்.';
    }
    if (widget.language == hindi) {
      return 'तस्वीरों का क्रम देखें और अगली तस्वीर चुनें।';
    }
    return 'Look at the picture pattern and choose the next picture.';
  }

  String get chooseTitle {
    if (widget.language == tamil) return 'அடுத்த படத்தை தேர்வு செய்யவும்';
    if (widget.language == hindi) return 'अगली तस्वीर चुनें';
    return 'Choose the next picture';
  }

  @override
  void initState() {
    super.initState();
    loadDifficulty();
  }

  Future<void> loadDifficulty() async {
    final recommended =
        await AiDifficultyService.getRecommendedDifficulty('Pattern Game');
    if (!mounted) return;
    setState(() {
      difficulty = recommended;
      nextDifficulty = recommended;
    });
    _prepareQuestion();
  }

  int get optionCount {
    if (difficulty == 'Easy') return 3;
    if (difficulty == 'Hard') return 5;
    return 4;
  }

  // Pattern rules are intentionally simple and unambiguous:
  // Easy   : ABA -> B, ABB -> A
  // Medium : ABAB -> A, ABCA -> B, ABCB -> A
  // Hard   : ABABA -> B, ABCAB -> C, ABCBA -> B
  // In every case, the calculated answer is explicitly inserted into options.
  void _prepareQuestion() {
    final pool = List<Map<String, dynamic>>.from(pictureBank)
      ..shuffle(random);

    final a = pool[0];
    final b = pool[1];
    final c = pool[2];

    late List<Map<String, dynamic>> visible;
    late Map<String, dynamic> answer;

    if (difficulty == 'Easy') {
      if (random.nextBool()) {
        visible = [a, b, a];
        answer = b;
      } else {
        visible = [a, b, b];
        answer = a;
      }
    } else if (difficulty == 'Medium') {
      final type = random.nextInt(3);
      if (type == 0) {
        visible = [a, b, a, b];
        answer = a;
      } else if (type == 1) {
        visible = [a, b, c, a];
        answer = b;
      } else {
        visible = [a, b, c, b];
        answer = a;
      }
    } else {
      final type = random.nextInt(3);
      if (type == 0) {
        visible = [a, b, a, b, a];
        answer = b;
      } else if (type == 1) {
        visible = [a, b, c, a, b];
        answer = c;
      } else {
        visible = [a, b, c, b, a];
        answer = b;
      }
    }

    final options = <Map<String, dynamic>>[answer];
    final used = <String>{answer['name'] as String};
    final wrongPool = List<Map<String, dynamic>>.from(pictureBank)
      ..shuffle(random);

    for (final picture in wrongPool) {
      final name = picture['name'] as String;
      if (used.contains(name)) continue;
      options.add(picture);
      used.add(name);
      if (options.length == optionCount) break;
    }

    options.shuffle(random);

    setState(() {
      sequence = visible;
      correctPicture = answer;
      answerOptions = options;
      answering = false;
    });
  }

  Future<void> speakInstruction() async {
    await VoiceService.speak(instruction, widget.language.code);
  }

  Future<void> answer(Map<String, dynamic> selected) async {
    if (answering || gameCompleted || correctPicture == null) return;

    setState(() {
      answering = true;
      attempts++;
      if (selected['name'] == correctPicture!['name']) score++;
    });

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    if (currentQuestion == 9) {
      await finishGame();
      return;
    }

    setState(() => currentQuestion++);
    _prepareQuestion();
  }

  Future<void> finishGame() async {
    if (gameCompleted) return;
    gameCompleted = true;

    final accuracy = (score / 10).clamp(0.0, 1.0).toDouble();
    final calculatedNextDifficulty =
        AiDifficultyService.calculateNextDifficulty(
      currentDifficulty: difficulty,
      accuracy: accuracy,
    );
    nextDifficulty = calculatedNextDifficulty;

    final savedOnline = await AiDifficultyService.saveGameResult(
      gameName: 'Pattern Game',
      score: score,
      accuracy: accuracy,
      attempts: attempts,
      difficulty: difficulty,
      nextDifficulty: calculatedNextDifficulty,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Game Complete', style: TextStyle(fontSize: 24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Score: $score / 10', style: const TextStyle(fontSize: 19)),
            const SizedBox(height: 8),
            Text('Accuracy: ${(accuracy * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 19)),
            const SizedBox(height: 8),
            Text('Current Difficulty: $difficulty',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Next Difficulty: $calculatedNextDifficulty',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              savedOnline
                  ? 'Result saved successfully.'
                  : 'Result saved on this device and will sync when internet returns.',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                difficulty = calculatedNextDifficulty;
                nextDifficulty = calculatedNextDifficulty;
                currentQuestion = 0;
                score = 0;
                attempts = 0;
                answering = false;
                gameCompleted = false;
                sequence = [];
                correctPicture = null;
                answerOptions = [];
              });
              _prepareQuestion();
            },
            child: const Text('Play Again', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _pictureTile(Map<String, dynamic> picture, {double size = 62}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5AA77F), width: 1.5),
      ),
      child: Icon(
        picture['icon'] as IconData,
        size: size * 0.55,
        color: const Color(0xFF2E7D5B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pattern Game', style: TextStyle(fontSize: 23)),
      ),
      body: SafeArea(
        child: sequence.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    // Difficulty is always clearly visible at the top.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6EF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF5AA77F), width: 1.5),
                      ),
                      child: Text(
                        'Difficulty: $difficulty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D5B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: speakInstruction,
                      icon: const Icon(Icons.volume_up_rounded),
                      iconSize: 32,
                    ),
                    Text('Question ${currentQuestion + 1} / 10',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const Text('Picture Pattern',
                                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final picture in sequence) _pictureTile(picture, size: 64),
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D5B),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.help_outline_rounded,
                                      color: Colors.white, size: 34),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(chooseTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: answerOptions.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (context, index) {
                        final picture = answerOptions[index];
                        return ElevatedButton(
                          onPressed: answering ? null : () => answer(picture),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _pictureTile(picture, size: 76),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Text('Score: $score',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ============================================================
// CAREGIVER PAGE
// ============================================================

class CaregiverPage extends StatelessWidget {
  const CaregiverPage({super.key});

  Future<void> _showAddReminderDialog(BuildContext context) async {
    final titleController = TextEditingController();
    String selectedType = 'Medicine';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Reminder', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Reminder title',
                        hintText: 'Example: Take morning medicine',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Reminder type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Medicine', child: Text('Medicine')),
                        DropdownMenuItem(value: 'Hydration', child: Text('Hydration')),
                        DropdownMenuItem(value: 'Appointment', child: Text('Appointment')),
                        DropdownMenuItem(value: 'Activity', child: Text('Activity')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => selectedType = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    await FirebaseFirestore.instance.collection('reminders').add({
                      'patientId': 'patient001',
                      'title': title,
                      'type': selectedType,
                      'completed': false,
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': 'caregiver',
                    });

                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder added successfully.')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    titleController.dispose();
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Dashboard', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add reminder',
            icon: const Icon(Icons.add_alert_rounded),
            onPressed: () => _showAddReminderDialog(context),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('patients').doc('patient001').snapshots(),
        builder: (context, patientSnapshot) {
          String patientName = 'Patient';
          String age = 'Not available';
          String language = 'Not available';

          if (patientSnapshot.hasData && patientSnapshot.data!.exists) {
            final data = patientSnapshot.data!.data() as Map<String, dynamic>;
            patientName = data['name']?.toString() ?? 'Patient';
            age = data['age']?.toString() ?? 'Not available';
            language = data['language']?.toString() ?? 'Not available';
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('game_results').where('patientId', isEqualTo: 'patient001').snapshots(),
            builder: (context, gameSnapshot) {
              final gameDocs = gameSnapshot.hasData ? gameSnapshot.data!.docs : <QueryDocumentSnapshot>[];
              final totalGames = gameDocs.length;
              double averageAccuracy = 0;
              final latestGames = <String, Map<String, dynamic>>{};

              for (final doc in gameDocs) {
                final data = doc.data() as Map<String, dynamic>;
                averageAccuracy += (data['accuracy'] as num?)?.toDouble() ?? 0;
                final gameName = data['gameName']?.toString() ?? 'Unknown';
                final old = latestGames[gameName];
                if (old == null) {
                  latestGames[gameName] = data;
                } else {
                  final newClientTime = data['clientTimestamp'];
                  final oldClientTime = old['clientTimestamp'];
                  final newServerTime = data['timestamp'];
                  final oldServerTime = old['timestamp'];

                  bool shouldReplace = false;
                  if (newClientTime is Timestamp && oldClientTime is Timestamp) {
                    shouldReplace = newClientTime.compareTo(oldClientTime) > 0;
                  } else if (newServerTime is Timestamp && oldServerTime is Timestamp) {
                    shouldReplace = newServerTime.compareTo(oldServerTime) > 0;
                  } else {
                    // Fallback for older records that do not have timestamps.
                    shouldReplace = true;
                  }

                  if (shouldReplace) {
                    latestGames[gameName] = data;
                  }
                }
              }
              if (gameDocs.isNotEmpty) averageAccuracy /= gameDocs.length;

              String overallRecommendation = 'Medium';
              if (averageAccuracy < 0.50) overallRecommendation = 'Easy';
              if (averageAccuracy >= 0.80) overallRecommendation = 'Hard';

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reminders').where('patientId', isEqualTo: 'patient001').snapshots(),
                builder: (context, reminderSnapshot) {
                  final reminderDocs = reminderSnapshot.hasData ? reminderSnapshot.data!.docs : <QueryDocumentSnapshot>[];
                  int completedReminders = 0;
                  int pendingReminders = 0;
                  for (final doc in reminderDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['completed'] == true) {
                      completedReminders++;
                    } else {
                      pendingReminders++;
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('activity_logs').where('patientId', isEqualTo: 'patient001').snapshots(),
                    builder: (context, activitySnapshot) {
                      final activityDocs = activitySnapshot.hasData ? activitySnapshot.data!.docs : <QueryDocumentSnapshot>[];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Patient Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF245B45))),
                                    const SizedBox(height: 15),
                                    Text('Name: $patientName', style: const TextStyle(fontSize: 19)),
                                    Text('Age: $age', style: const TextStyle(fontSize: 19)),
                                    Text('Language: $language', style: const TextStyle(fontSize: 19)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            const Text('Monitoring', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF245B45))),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _monitorCard(Icons.games_rounded, 'Games', '$totalGames')),
                                const SizedBox(width: 10),
                                Expanded(child: _monitorCard(Icons.percent_rounded, 'Accuracy', '${(averageAccuracy * 100).toStringAsFixed(0)}%')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _monitorCard(Icons.check_circle_rounded, 'Completed', '$completedReminders')),
                                const SizedBox(width: 10),
                                Expanded(child: _monitorCard(Icons.pending_actions_rounded, 'Pending', '$pendingReminders')),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Card(
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.notifications_active_rounded, size: 32, color: Color(0xFF2E7D5B)),
                                        SizedBox(width: 10),
                                        Text('Reminder Monitoring', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    if (reminderDocs.isEmpty)
                                      const Text('No reminders created yet.', style: TextStyle(fontSize: 17))
                                    else
                                      ...reminderDocs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final title = data['title']?.toString() ?? 'Reminder';
                                        final type = data['type']?.toString() ?? 'Activity';
                                        final completed = data['completed'] == true;
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(completed ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: completed ? const Color(0xFF2E7D5B) : Colors.orange.shade800, size: 30),
                                          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          subtitle: Text('$type • ${completed ? 'Completed' : 'Pending'}', style: const TextStyle(fontSize: 16)),
                                        );
                                      }),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showAddReminderDialog(context),
                                        icon: const Icon(Icons.add_alert_rounded),
                                        label: const Text('Create Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Card(
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.psychology_rounded, size: 32, color: Color(0xFF2E7D5B)),
                                        SizedBox(width: 10),
                                        Text('AI Cognitive Insights', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text('Overall Recommended Difficulty: $overallRecommendation', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 15),
                                    if (latestGames.isEmpty)
                                      const Text('No game data available yet.', style: TextStyle(fontSize: 17))
                                    else
                                      ...latestGames.entries.map((entry) {
                                        final data = entry.value;
                                        final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0;
                                        final next = data['nextDifficulty']?.toString() ?? 'Medium';
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 14),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(color: const Color(0xFFEAF6EF), borderRadius: BorderRadius.circular(12)),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(entry.key, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 6),
                                                Text('Accuracy: ${(accuracy * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 17)),
                                                Text('Next Difficulty: $next', style: const TextStyle(fontSize: 17)),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Card(
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.history_rounded, size: 32, color: Color(0xFF2E7D5B)),
                                        SizedBox(width: 10),
                                        Text('Activity History', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Text('Recorded activities: ${activityDocs.length}', style: const TextStyle(fontSize: 18)),
                                    const SizedBox(height: 10),
                                    if (activityDocs.isEmpty)
                                      const Text('No activity recorded yet.', style: TextStyle(fontSize: 17))
                                    else
                                      ...activityDocs.reversed.take(5).map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final activity = data['activity']?.toString() ?? 'Activity';
                                        final details = data['details']?.toString() ?? '';
                                        final status = data['status']?.toString() ?? 'Completed';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.task_alt_rounded, color: Color(0xFF2E7D5B)),
                                          title: Text(activity, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          subtitle: Text(details.isEmpty ? status : '$details • $status', style: const TextStyle(fontSize: 16)),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            InfoCard(
                              icon: pendingReminders > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                              title: pendingReminders > 0 ? 'Caregiver Alert' : 'Caregiver Status',
                              subtitle: pendingReminders > 0 ? '$pendingReminders reminder(s) are still pending.' : 'All current reminders are completed.',
                            ),
                            const InfoCard(
                              icon: Icons.cloud_sync_rounded,
                              title: 'Data Sync',
                              subtitle: 'Patient activity and reminder status are stored in Firebase.',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _monitorCard(IconData icon, String title, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF2E7D5B)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

