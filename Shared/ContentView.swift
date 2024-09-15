//
//  ContentView.swift
//  Shared
//
//  Created by Rippel on 9/10/24.
//

import SwiftUI
import AuthenticationServices
import Foundation
import StoreKit

struct GitaVerse: Codable, Hashable {
    let verseNumber: String
    let sanskritVerse: String
    let englishTransliteration: String
    let wordMeanings: String
    let translation: String
    let purport: String

    enum CodingKeys: String, CodingKey {
        case verseNumber
        case sanskritVerse = "sanskrit verse"
        case englishTransliteration = "english transliteration"
        case wordMeanings = "word meanings"
        case translation
        case purport
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(verseNumber)
    }
    
    static func == (lhs: GitaVerse, rhs: GitaVerse) -> Bool {
        return lhs.verseNumber == rhs.verseNumber
    }
}

class GitaService {
    static let shared = GitaService()
    private let apiBaseURL = "https://bhagavad-gita-api.p.rapidapi.com"
    private let rapidAPIKey = "eae39e1046msh834cf9fc2bc4bc0p19ae73jsn32652f09a888"
    private let rapidAPIHost = "bhagavad-gita-api.p.rapidapi.com"
    
    private var revealedVerses: Set<String> = []
    
    init() {
        loadRevealedVerses()
    }
    
    func getRandomVerse(completion: @escaping (Result<GitaVerse, Error>) -> Void) {
        func attemptFetch(retries: Int = 3) {
            guard retries > 0 else {
                completion(.failure(NSError(domain: "Failed to fetch verse after multiple attempts", code: 0, userInfo: nil)))
                return
            }
            
            let chapters = 18 // Total number of chapters in Bhagavad Gita
            let randomChapter = Int.random(in: 1...chapters)
            let randomVerse = Int.random(in: 1...78) // Assuming a maximum of 78 verses per chapter
            
            let urlString = "\(apiBaseURL)/\(randomChapter)/\(randomVerse)"
            guard let url = URL(string: urlString) else {
                completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
                return
            }
            
            print("Requesting URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue(rapidAPIHost, forHTTPHeaderField: "x-rapidapi-host")
            request.addValue(rapidAPIKey, forHTTPHeaderField: "x-rapidapi-key")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Network Error: \(error.localizedDescription)")
                    attemptFetch(retries: retries - 1)
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    attemptFetch(retries: retries - 1)
                    return
                }
                
                print("Received data: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
                
                do {
                    let jsonResult = try JSONDecoder().decode([String: GitaVerse].self, from: data)
                    if let verse = jsonResult.values.first {
                        completion(.success(verse))
                    } else {
                        print("No verse found in the response")
                        attemptFetch(retries: retries - 1)
                    }
                } catch {
                    print("Decoding error: \(error)")
                    print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
                    attemptFetch(retries: retries - 1)
                }
            }.resume()
        }
        
        attemptFetch()
    }
    
    func getRevealedVerseCount() -> Int {
        return revealedVerses.count
    }
    
    func markVerseAsRevealed(_ verseNumber: String) {
        revealedVerses.insert(verseNumber)
        saveRevealedVerses()
    }
    
    private func loadRevealedVerses() {
        if let savedVerses = UserDefaults.standard.array(forKey: "revealedVerses") as? [String] {
            revealedVerses = Set(savedVerses)
        }
    }
    
    private func saveRevealedVerses() {
        UserDefaults.standard.set(Array(revealedVerses), forKey: "revealedVerses")
    }
    
    func isVerseRevealed(_ verseNumber: String) -> Bool {
        return revealedVerses.contains(verseNumber)
    }
}

struct ContentView: View {
    @State private var isLoggedIn = false
    
    var body: some View {
        if isLoggedIn {
            LandingView()
        } else {
            LoginView(onLoginSuccess: {
                isLoggedIn = true
            })
        }
    }
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    var onLoginSuccess: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: login) {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: { showSignUp = true }) {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: signInWithGoogle) {
                    HStack {
                        Image("google_logo") // Add this image to your assets
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleSignInWithAppleResult(result)
                    }
                )
                .frame(height: 50)
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("Login")
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(onSignUpComplete: onLoginSuccess)
        }
    }
    
    func login() {
        // Implement your login logic here
        // For now, we'll just call onLoginSuccess
        onLoginSuccess()
    }
    
    func signInWithGoogle() {
        // Implement Google Sign-In
        print("Google Sign-In tapped")
    }
    
    func handleSignInWithAppleResult(_ result: Result<ASAuthorization, Error>) {
        // Handle Apple Sign-In result
        switch result {
        case .success(let authorization):
            // Handle successful sign-in
            print("Successfully signed in with Apple")
            onLoginSuccess()
        case .failure(let error):
            print("Failed to sign in with Apple: \(error.localizedDescription)")
        }
    }
}

struct LandingView: View {
    @State private var isMenuOpen = false
    @State private var savedLessons: [Lesson] = []
    @State private var selectedTab = 0
    @State private var revealedVerseCount = 0
    @State private var showDonateView = false
    @State private var totalVerses = 700 // Total number of verses in Bhagavad Gita
    @State private var isVerseRevealed = false
    
    var body: some View {
        NavigationView {
            ZStack {
                TabView(selection: $selectedTab) {
                    LessonView(onSaveToggle: { lesson, isSaving in
                        if isSaving {
                            savedLessons.append(lesson)
                        } else {
                            savedLessons.removeAll { $0.id == lesson.id }
                        }
                    }, onVerseRevealed: {
                        incrementRevealedVerseCount()
                    }, isVerseRevealed: $isVerseRevealed)
                    .tag(0)
                    SavedLessonsView(savedLessons: $savedLessons)
                        .tag(1)
                    ProfileView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                VStack {
                    Spacer()
                    HStack {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(selectedTab == index ? Color.black : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom)
                }
                
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        MenuView(isOpen: $isMenuOpen, savedLessons: savedLessons, showDonateView: $showDonateView)
                            .frame(width: geometry.size.width * 0.75)
                            .offset(x: isMenuOpen ? 0 : -geometry.size.width * 0.75)
                            .animation(.default, value: isMenuOpen)
                        
                        Color.black.opacity(isMenuOpen ? 0.5 : 0)
                            .onTapGesture {
                                isMenuOpen = false
                            }
                    }
                }
                .edgesIgnoringSafeArea(.all)
            }
            .navigationBarItems(leading: Button(action: { isMenuOpen.toggle() }) {
                Image(systemName: "line.horizontal.3")
            }, trailing: HStack {
                Image(systemName: "book.circle.fill")
                    .foregroundColor(.blue)
                    .overlay(
                        Text("\(revealedVerseCount)/700")
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
            })
            .navigationBarTitle("Gita Pro", displayMode: .inline)
        }
        .onAppear {
            loadRevealedVerseCount()
        }
        .sheet(isPresented: $showDonateView) {
            DonateView()
        }
    }
    
    func loadRevealedVerseCount() {
        revealedVerseCount = GitaService.shared.getRevealedVerseCount()
    }
    
    func incrementRevealedVerseCount() {
        revealedVerseCount = GitaService.shared.getRevealedVerseCount()
    }
}

struct RevealVerseView: View {
    var onReveal: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: {
                withAnimation(.spring()) {
                    onReveal()
                }
            }) {
                Text("Reveal Verse")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
            Spacer()
        }
    }
}

struct LessonView: View {
    @State private var currentVerse: GitaVerse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onSaveToggle: (Lesson, Bool) -> Void
    var onVerseRevealed: () -> Void
    @Binding var isVerseRevealed: Bool
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Revealing verse...")
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                Button("Try Again") {
                    revealRandomVerse()
                }
                .padding()
            } else if let verse = currentVerse {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Verse \(verse.verseNumber)")
                            .font(.headline)
                        Text(verse.sanskritVerse)
                            .font(.subheadline)
                            .italic()
                        Text(verse.englishTransliteration)
                            .font(.subheadline)
                        Text(verse.translation)
                            .font(.body)
                        Text("Word Meanings:")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text(verse.wordMeanings)
                            .font(.caption)
                    }
                    .padding()
                }
            } else {
                RevealVerseView(onReveal: revealRandomVerse)
            }
        }
    }
    
    private func revealRandomVerse() {
        isLoading = true
        errorMessage = nil
        
        GitaService.shared.getRandomVerse { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let verse):
                    if !GitaService.shared.isVerseRevealed(verse.verseNumber) {
                        currentVerse = verse
                        GitaService.shared.markVerseAsRevealed(verse.verseNumber)
                        onVerseRevealed()
                        isVerseRevealed = true
                    } else {
                        revealRandomVerse() // Try again if verse has already been revealed
                    }
                case .failure(let error):
                    errorMessage = "Failed to fetch verse. Please try again. Error: \(error.localizedDescription)"
                    print("Error fetching verse: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct SavedLessonsView: View {
    @Binding var savedLessons: [Lesson]
    
    var body: some View {
        List {
            ForEach(savedLessons) { lesson in
                VStack(alignment: .leading) {
                    Text(lesson.title)
                        .font(.headline)
                    Text(lesson.content)
                        .font(.body)
                        .lineLimit(2)
                    Text(lesson.savedDate ?? lesson.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete(perform: deleteLessons)
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Saved Lessons")
    }
    
    func deleteLessons(at offsets: IndexSet) {
        savedLessons.remove(atOffsets: offsets)
    }
}

struct ProfileView: View {
    @State private var revealedVerseCount = 0
    @State private var totalVerses = 700
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Progress")
                    .font(.headline)
                
                ProgressView(value: Double(revealedVerseCount), total: Double(totalVerses))
                
                Text("\(revealedVerseCount) out of \(totalVerses) verses revealed")
                    .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Add more profile details here
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadRevealedVerseCount()
        }
    }
    
    private func loadRevealedVerseCount() {
        revealedVerseCount = UserDefaults.standard.integer(forKey: "revealedVerseCount")
    }
}

struct MenuView: View {
    @Binding var isOpen: Bool
    let savedLessons: [Lesson]
    @Binding var showDonateView: Bool
    @State private var selectedLesson: Lesson?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Saved Lessons")
                .font(.headline)
                .padding(.bottom, 8)
            
            if savedLessons.isEmpty {
                Text("No saved lessons yet")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    ForEach(savedLessons) { lesson in
                        Button(action: { selectedLesson = lesson }) {
                            VStack(alignment: .leading) {
                                Text(lesson.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(lesson.savedDate ?? lesson.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: { showDonateView = true }) {
                Text("Donate")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .sheet(item: $selectedLesson) { lesson in
            SavedLessonDetailView(lesson: lesson, allLessons: savedLessons)
        }
    }
}

struct DonateView: View {
    @State private var donationAmount = ""
    @State private var showThankYouMessage = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Support Our Mission")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your donation helps us continue spreading the wisdom of the Bhagavad Gita.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                HStack {
                    Text("$")
                    TextField("Amount", text: $donationAmount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                Button(action: processDonation) {
                    Text("Donate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Donate", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .modifier(InteractiveDismissModifier())
        .alert(isPresented: $showThankYouMessage) {
            Alert(
                title: Text("Thank You!"),
                message: Text("Your donation of $\(donationAmount) to Gita Pro Foundation is greatly appreciated. Your support helps us continue our important work."),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    func processDonation() {
        guard let amount = Double(donationAmount), amount > 0 else {
            // Show an error message for invalid input
            return
        }
        
        // Here you would integrate with StoreKit for in-app purchases
        // For this example, we'll just show a thank you message
        showThankYouMessage = true
    }
}

struct InteractiveDismissModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.interactiveDismissDisabled(true)
        } else {
            content
        }
    }
}

struct SavedLessonDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    let lesson: Lesson
    let allLessons: [Lesson]
    @State private var currentIndex: Int
    @State private var selectedSegment = 0
    
    init(lesson: Lesson, allLessons: [Lesson]) {
        self.lesson = lesson
        self.allLessons = allLessons
        self._currentIndex = State(initialValue: allLessons.firstIndex(where: { $0.id == lesson.id }) ?? 0)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(currentLesson.title)
                    .font(.title)
                
                Picker("", selection: $selectedSegment) {
                    Text("Sanskrit").tag(0)
                    Text("Translation").tag(1)
                    Text("Application").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedSegment {
                        case 0:
                            Text(currentLesson.content)
                                .font(.body)
                                .italic()
                            Text(currentLesson.transliteration)
                                .font(.body)
                        case 1:
                            Text(currentLesson.translation)
                                .font(.body)
                        case 2:
                            Text(currentLesson.application)
                                .font(.body)
                        default:
                            EmptyView()
                        }
                    }
                }
                
                Text(currentLesson.savedDate ?? currentLesson.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width < 0 {
                            // Swipe left
                            if currentIndex < allLessons.count - 1 {
                                currentIndex += 1
                            }
                        } else if value.translation.width > 0 {
                            // Swipe right
                            if currentIndex > 0 {
                                currentIndex -= 1
                            }
                        }
                    }
            )
            .navigationBarTitle("Saved Lesson", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    var currentLesson: Lesson {
        allLessons[currentIndex]
    }
}

struct Lesson: Identifiable {
    let id: UUID
    let title: String
    let content: String
    let transliteration: String
    let translation: String
    let application: String
    let date: Date
    let savedDate: Date?
    
    init(id: UUID = UUID(), title: String, content: String, transliteration: String, translation: String, application: String, date: Date, savedDate: Date?) {
        self.id = id
        self.title = title
        self.content = content
        self.transliteration = transliteration
        self.translation = translation
        self.application = application
        self.date = date
        self.savedDate = savedDate
    }
}

struct GentleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct WhiteButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(\.presentationMode) var presentationMode
    var onSignUpComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Your Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: createAccount) {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Sign Up", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    func createAccount() {
        // Here you would typically validate the input and call your backend API
        // For this example, we'll just simulate a successful account creation
        onSignUpComplete()
        presentationMode.wrappedValue.dismiss()
    }
}

// Preview for ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Preview for LandingView
struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        LandingView()
    }
}

// Preview for MenuView
struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(isOpen: .constant(true), savedLessons: [
            Lesson(title: "Sample Lesson 1", content: "Content 1", transliteration: "Transliteration 1", translation: "Translation 1", application: "Application 1", date: Date(), savedDate: Date()),
            Lesson(title: "Sample Lesson 2", content: "Content 2", transliteration: "Transliteration 2", translation: "Translation 2", application: "Application 2", date: Date(), savedDate: nil)
        ], showDonateView: .constant(false))
    }
}

// Preview for LessonView
struct LessonView_Previews: PreviewProvider {
    static var previews: some View {
        LessonView(onSaveToggle: { _, _ in }, onVerseRevealed: {}, isVerseRevealed: .constant(true))
    }
}

// Preview for SavedLessonDetailView
struct SavedLessonDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SavedLessonDetailView(lesson: Lesson(title: "Sample Saved Lesson", content: "This is a saved lesson content.", transliteration: "Transliteration", translation: "Translation", application: "Application", date: Date(), savedDate: Date()), allLessons: [
            Lesson(title: "Sample Lesson 1", content: "Content 1", transliteration: "Transliteration 1", translation: "Translation 1", application: "Application 1", date: Date(), savedDate: Date()),
            Lesson(title: "Sample Lesson 2", content: "Content 2", transliteration: "Transliteration 2", translation: "Translation 2", application: "Application 2", date: Date(), savedDate: Date())
        ])
    }
}

// Preview for SignUpView
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(onSignUpComplete: {})
    }
}
