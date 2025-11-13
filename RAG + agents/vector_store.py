import os
from dotenv import load_dotenv
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_text_splitters import CharacterTextSplitter
from langchain_core.documents import Document
from search_agent import load_texts

load_dotenv()

FAISS_INDEX_PATH = "faiss_index"

embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

def create_and_save_vector_store(texts):
    if not texts:
        print("No texts to process.")
        return

    print("Starting embedding process...")

    docs = [Document(page_content=text) for text in texts]

    text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=200, separator="\n")
    split_docs = text_splitter.split_documents(docs)

    print("Creating FAISS index...")
    vectorstore = FAISS.from_documents(split_docs, embeddings)

    vectorstore.save_local(FAISS_INDEX_PATH)
    print("FAISS index saved successfully!")

if __name__ == "__main__":
    print("Loading menu data...")
    all_texts = load_texts()
    create_and_save_vector_store(all_texts)
