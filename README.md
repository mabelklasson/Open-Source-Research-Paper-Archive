# 📚 Open-Source Research Paper Archive (Research)

An immutable, decentralized archive for academic papers built on the Stacks blockchain, ensuring permanent access and preventing censorship.

## 🎯 Overview

The Research smart contract provides a comprehensive platform for academics to:
- 📄 Submit and publish research papers immutably
- 👥 Register as verified authors with institutional affiliations  
- 🔍 Access papers through IPFS distributed storage
- ⭐ Conduct peer reviews and citations
- 💰 Monetize research through access fees
- 🏆 Build academic reputation scores

## ✨ Features

### 🔐 Author Management
- Register with name, institution, and email
- Track publication count and reputation score
- Unique principal-based identification

### 📝 Paper Lifecycle
- **Submit**: Upload papers to IPFS with metadata
- **Publish**: Make papers publicly available
- **Access**: Controlled access with optional fees
- **Review**: Peer review system with scoring
- **Citation**: Track paper citations and impact

### 💵 Economic Model
- Submission fee: 1 STX
- Publication fee: 5 STX  
- Custom access fees set by authors
- Revenue sharing to paper authors

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks Wallet](https://www.hiro.so/wallet)
- IPFS node for paper storage

### Installation

```bash
# Clone the repository
git clone https://github.com/your-repo/research-archive
cd research-archive

# Initialize Clarinet project
clarinet integrate

# Check contract
clarinet check
```

## 📖 Usage Guide

### 1. 👤 Register as Author

```clarity
(contract-call? .Research register-author 
  "Dr. Jane Smith" 
  "MIT Computer Science" 
  "jane@mit.edu")
```

### 2. 📄 Submit Research Paper

```clarity
(contract-call? .Research submit-paper
  "Quantum Computing Applications"
  "This paper explores novel applications of quantum computing..."
  (list 'SP1ABC123... 'SP2DEF456...)  ; Author principals
  "QmYourIPFSHashHere123456789"
  (list "quantum" "computing" "algorithms")
  "Computer Science"
  u1000000)  ; Access fee in microSTX
```

### 3. 🌐 Publish Paper

```clarity
(contract-call? .Research publish-paper u1)
```

### 4. 🔓 Access Paper Content

```clarity
(contract-call? .Research access-paper u1)
```

### 5. ⭐ Review Paper

```clarity
(contract-call? .Research review-paper u1 u8 "Excellent methodology and results")
```

### 6. 📚 Cite Paper

```clarity
(contract-call? .Research cite-paper u2 u1)  ; Your paper cites paper #1
```

## 🔍 Read-Only Functions

### Get Paper Information
```clarity
(contract-call? .Research get-paper u1)
```

### Get Author Details  
```clarity
(contract-call? .Research get-author 'SP1ABC123...)
```

### Get Contract Statistics
```clarity
(contract-call? .Research get-contract-stats)
```

### Check Paper Access
```clarity
(contract-call? .Research has-paper-access u1 'SP1ABC123...)
```

## 📊 Data Structures

### Author Record
```clarity
{
  name: (string-ascii 100),
  institution: (string-ascii 200), 
  email: (string-ascii 100),
  papers-count: uint,
  reputation-score: uint,
  joined-at: uint
}
```

### Paper Record
```clarity
{
  title: (string-ascii 200),
  abstract: (string-ascii 1000),
  authors: (list 10 principal),
  ipfs-hash: (string-ascii 100),
  keywords: (list 20 (string-ascii 50)),
  category: (string-ascii 50),
  submission-date: uint,
  publication-date: (optional uint),
  status: (string-ascii 20),
  peer-reviews: uint,
  citations: uint,
  access-fee: uint,
  submitter: principal
}
```

## 🔒 Security Features

- ✅ Author verification required for submissions
- ✅ Immutable paper storage via IPFS
- ✅ Access control with STX payments  
- ✅ Peer review integrity
- ✅ Citation tracking prevents manipulation
- ✅ Economic incentives prevent spam

## ⚠️ Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 400 | ERR_INVALID_AUTHOR | Author not registered |
| 401 | ERR_NOT_AUTHORIZED | Insufficient permissions |
| 402 | ERR_INVALID_PAPER | Invalid paper data |
| 403 | ERR_AUTHOR_EXISTS | Author already registered |
| 404 | ERR_PAPER_NOT_FOUND | Paper doesn't exist |
| 405 | ERR_NOT_PAPER_AUTHOR | Not the paper author |
| 406 | ERR_PAPER_ALREADY_PUBLISHED | Paper already published |
| 407 | ERR_INSUFFICIENT_BALANCE | Insufficient STX balance |
| 409 | ERR_PAPER_EXISTS | Paper already exists |

## 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test
npm test tests/research_test.ts
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Roadmap

- [ ] 🔍 Advanced search functionality
- [ ] 🏷️ DOI integration  
- [ ] 📊 Analytics dashboard
- [ ] 🤖 AI-powered paper recommendations
- [ ] 🔗 Cross-chain compatibility
- [ ] 📱 Mobile app interface

## 💬 Community

- [Discord](https://discord.gg/research-archive)
- [Twitter](https://twitter.com/research_archive)
- [Telegram](https://t.me/research_archive)

---

*Built with ❤️ on Stacks blockchain for the academic community* 🎓
