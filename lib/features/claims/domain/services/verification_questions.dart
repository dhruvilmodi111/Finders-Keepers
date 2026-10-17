class VerificationQuestions {
  VerificationQuestions._();

  static String getCategoryQuestion(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return 'What is the device brand, exact color, and what does the lockscreen wallpaper / casing look like?';
      case 'id cards':
        return 'What is the full name and registration number printed on this ID card?';
      case 'books & notes':
        return 'What subject/course code is this notebook for, and what is written on the first few pages?';
      case 'keys':
        return 'How many keys are on the ring, and describe any keychain mascot, tag, or ribbon attached.';
      case 'clothing':
        return 'What is the brand, size, and describe any distinctive design, graphic, or tear?';
      case 'bags & wallets':
        return 'What color is the inner lining or describe any non-confidential item inside?';
      case 'bottles':
        return 'What is the bottle brand/model, color, and describe any stickers or marks?';
      case 'watches & jewelry':
        return 'What is the strap/chain material, brand, and color of the dial/pendant?';
      case 'others':
      default:
        return 'Describe specific distinctive marks, brand, scratches, or wear that prove this item is yours.';
    }
  }

  static String getHiddenDetailQuestion() {
    return 'Secret Detail: The finder recorded a secret identifier that only the genuine owner should know. What is it?';
  }
}
