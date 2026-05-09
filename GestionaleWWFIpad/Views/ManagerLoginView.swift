import SwiftUI

struct ManagerLoginView: View {
    @EnvironmentObject var managerSession: ManagerSession
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color("WWFGreen").opacity(0.12))
                                .frame(width: 100, height: 100)
                            Image(systemName: "leaf.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(Color("WWFGreen"))
                        }
                        Text("Portale Gestori")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Oasi WWF degli Astroni")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 48)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email").font(.caption).foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.secondary)
                                TextField("gestore@wwf.it", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .focused($focusedField, equals: .email)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password").font(.caption).foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.secondary)
                                if showPassword {
                                    TextField("••••••••", text: $password)
                                        .focused($focusedField, equals: .password)
                                } else {
                                    SecureField("••••••••", text: $password)
                                        .focused($focusedField, equals: .password)
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let error = managerSession.loginError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Button {
                            focusedField = nil
                            managerSession.login(email: email, password: password)
                        } label: {
                            Text("Accedi")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    // ← validazione diretta sui binding, nessun computed property
                                    (email.isEmpty || password.isEmpty) ? Color.gray : Color("WWFGreen")
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        // ← disabled separato così reagisce ai cambiamenti di stato
                        .disabled(email.isEmpty || password.isEmpty)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Area Riservata")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
